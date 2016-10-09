defmodule Paracusia.MpdClient do
  use GenServer
  @moduledoc false
  require Logger
  alias Paracusia.MpdTypes
  alias Paracusia.ConnectionState, as: ConnState


  # TODO consistency: Make sure that all public functions return {:ok, _} or :{error, _}
  ## Client API

  # Connect to the MPD server.
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_and_recv(msg) do
    GenServer.call(__MODULE__, {:send_and_recv, msg})
  end

  def send_and_ack(msg) do
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end


  @doc"""
  Returns the current status of the player.
  """
  @spec status() :: {:ok, %Paracusia.PlayerState.Status{}} | MpdTypes.mpd_error
  def status do
    GenServer.call(__MODULE__, :status)
  end

  def playlist_state do
    # Caution: the status record will contain obsolete information (i.e., "elapsed" and "time").
    # Should get the new status via "status" instead, which calls the socket.
    GenServer.call(__MODULE__, :playlist_state)
  end

  @doc"""
  Sets the volume. Volume must be between 0 and 100.
  """
  @spec setvol(integer) :: :ok | MpdTypes.mpd_error
  def setvol(volume) do
    GenServer.call(__MODULE__, {:setvol, volume})
  end

  def debug(data) do
    GenServer.call(__MODULE__, {:debug, data})
  end

  @spec recv_until_newline(port, String.t) :: String.t
  defp recv_until_newline(sock, prev_answer \\ "") do
    answer = case :gen_tcp.recv(sock, 0) do
      {:ok, m} -> prev_answer <> m
    end
    if answer |> String.ends_with?("\n") do
      answer
    else
      recv_until_newline(sock, answer)
    end
  end

  @spec recv_until_ok(port, String.t) :: {:ok, String.t} | MpdTypes.mpd_error
  defp recv_until_ok(sock, prev_answer \\ "") do
    complete_msg = recv_until_newline(sock, prev_answer)
    if complete_msg |> String.ends_with?("OK\n") do
      {:ok, complete_msg |> String.trim_trailing("OK\n")}
    else
      case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, [capture: :all_but_first]) do
        [errorcode, command, message] ->
          {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
        nil ->
          recv_until_ok(sock, complete_msg)
      end
    end
  end

  ## Server Callbacks

  defp connect_retry(hostname, port, [attempt: attempt,
                                     retry_after: retry_after,
                                     max_attempts: max_attempts]) do
    if attempt > max_attempts do
      reason = "Connection establishment failed, maximum number of connection attempts exceeded."
      _ = Logger.error reason
      raise reason
    end
    case :gen_tcp.connect(hostname, port, [:binary, active: false]) do
      {:ok, sock} -> sock
      {:error, :econnrefused} ->
        :timer.sleep(retry_after)
        _ = Logger.error "Connection refused, retry after #{retry_after} ms."
        connect_retry(hostname, port,
                      [attempt: attempt + 1, retry_after: retry_after, max_attempts: max_attempts])
    end
  end

  def init([retry_after: retry_after, max_attempts: max_attempts]) do
    :erlang.process_flag(:trap_exit, true)  # to close mpd connection after application stop
    # TODO if MPD_HOST is an absolute path, we should attempt to connect to a unix domain socket.
    {hostname, password} = case System.get_env("MPD_HOST") do
      nil -> {'localhost', nil}
      hostname -> case String.split(hostname, "@") do
        [hostname] -> {to_charlist(hostname), nil}
        [password, hostname] -> {to_charlist(hostname), password}
      end
    end
    port = case System.get_env("MPD_PORT") do
      nil -> 6600
      port -> case Integer.parse(port) do
        {p, ""} -> p
      end
    end
    # When the GenServer is restarted as a result of the MPD server restarting (and therefore
    # closing its connection to Paracusia), connecting to MPD may fail if MPD takes longer to
    # restart than Paracusia. For that reason, we retry connection establishment.
    sock_passive = connect_retry(hostname, port,
                                 attempt: 1, retry_after: retry_after, max_attempts: max_attempts)
    {:ok, sock_active}  = :gen_tcp.connect(hostname, port, [:binary, active: :false])
    "OK MPD" <> _ = recv_until_newline(sock_passive)
    "OK MPD" <> _ = recv_until_newline(sock_active)
    if password do
      :ok = :gen_tcp.send(sock_active, "password #{password}\n")
      :ok = :gen_tcp.send(sock_passive, "password #{password}\n")
      :ok = ok_from_socket(sock_passive)
      :ok = ok_from_socket(sock_active)
    end
    :ok = :gen_tcp.send(sock_active, "idle\n")
    :ok = :inet.setopts(sock_active, [active: :once])
    {:ok, _} = :timer.send_interval(6000, :send_ping)
    conn_state = %ConnState{:sock_passive => sock_passive,
                            :sock_active => sock_active}
    {:ok, conn_state}
  end

  def player_state do
    GenServer.call(__MODULE__, :player_state)
  end

  defp read_until_next_newline(socket, prev_msg) do
    case :gen_tcp.recv(socket, 1) do
      {:ok, "\n"} -> prev_msg <> "\n"
      {:ok, msg}  -> read_until_next_newline(socket, prev_msg <> msg)
    end
  end

  defp ok_from_socket(socket) do
    case :gen_tcp.recv(socket, 3) do
      {:ok, "OK\n"} -> :ok
      {:ok, "ACK"} ->
        complete_msg = read_until_next_newline(socket, "ACK")
        case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, [capture: :all_but_first]) do
          [errorcode, command, message] ->
            {:error, {errorcode,
              "error #{errorcode} while executing command #{command}: #{message}"}}
        end
    end
  end


  ## See https://www.musicpd.org/doc/protocol/command_reference.html
  ## for an overview of all idle commands.

  defp process_message(msg), do:
    process_message(msg, [])
  defp process_message("changed: database\n" <> rest, events), do:
    process_message(rest, [:database_changed | events])
  defp process_message("changed: update\n" <> rest, events), do:
    process_message(rest, [:update_changed | events])
  defp process_message("changed: stored_playlist\n" <> rest, events), do:
    process_message(rest, [:stored_playlist_changed | events])
  defp process_message("changed: playlist\n" <> rest, events), do:
    process_message(rest, [:playlist_changed | events])
  defp process_message("changed: player\n" <> rest, events), do:
    process_message(rest, [:player_changed | events])
  defp process_message("changed: mixer\n" <> rest, events), do:
    process_message(rest, [:mixer_changed | events])
  defp process_message("changed: output\n" <> rest, events), do:
    process_message(rest, [:outputs_changed | events])
  defp process_message("changed: options\n" <> rest, events), do:
    process_message(rest, [:options_changed | events])
  defp process_message("changed: sticker\n" <> rest, events), do:
    process_message(rest, [:sticker_changed | events])
  defp process_message("changed: subscription\n" <> rest, events), do:
    process_message(rest, [:subscription_changed | events])
  defp process_message("changed: message\n" <> rest, events), do:
    process_message(rest, [:message_changed | events])
  defp process_message("OK\n", events), do:
    events

  defp ping(socket) do
    :ok = :gen_tcp.send(socket, "ping\n")
    ok_from_socket(socket)
  end

  def handle_call({:debug, data}, _from, state = %ConnState{}) do
    :ok = :gen_tcp.send(state.sock_passive, data)
    {:ok, answer} = recv_until_ok(state.sock_passive)
    {:reply, answer, state}
  end

  def handle_call({:send_and_ack, msg}, _from, state = %ConnState{}) do
    :ok = :gen_tcp.send(state.sock_passive, msg)
    reply = ok_from_socket(state.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:send_and_recv, msg}, _from, state = %ConnState{}) do
    :ok = :gen_tcp.send(state.sock_passive, msg)
    reply = recv_until_ok(state.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:kill, _from, state = %ConnState{}) do
    :ok = :gen_tcp.send(state.sock_passive, "kill\n")
    {:reply, :ok, state}
  end

  def handle_call(:ping, _from, state = %ConnState{}) do
    {:reply, ping(state.sock_passive), state}
  end

  def handle_info(:send_ping, state = %ConnState{}) do
    :ok = ping(state.sock_passive)
    {:noreply, state}
  end

  def handle_info({:tcp, _, msg}, state = %ConnState{}) do
    complete_msg =
      if String.ends_with?(msg, "OK\n") do
        msg
      else
        case recv_until_ok(state.sock_active, msg) do
          {:ok, without_trailing_ok} -> without_trailing_ok <> "OK\n"
        end
      end
    events = process_message(complete_msg)
    GenServer.cast(Paracusia.PlayerState, {:events, events})
    # We have received this message as a result of having sent idle. We need to resend idle
    # each time after we have obtained a new idle message.
    :ok = :gen_tcp.send(state.sock_active, "idle\n")
    :ok = :inet.setopts(state.sock_active, [active: :once])
    {:noreply, state}
  end

  def terminate(:shutdown, state = %ConnState{}) do
    _ = Logger.debug "Teardown connection to MPD."
    :ok = :gen_tcp.send(state.sock_active, "close\n")
    :ok = :gen_tcp.send(state.sock_passive, "close\n")
    :ok = :gen_tcp.close(state.sock_active)
    :ok = :gen_tcp.close(state.sock_passive)
    :ok
  end

end
