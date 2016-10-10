defmodule Paracusia.MpdClient do
  use GenServer
  @moduledoc false
  require Logger
  alias Paracusia.MpdTypes


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
  Sets the volume. Volume must be between 0 and 100.
  """
  @spec setvol(integer) :: :ok | MpdTypes.mpd_error
  def setvol(volume) do
    GenServer.call(__MODULE__, {:setvol, volume})
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
      case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, capture: :all_but_first) do
        [errorcode, command, message] ->
          {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
        nil ->
          recv_until_ok(sock, complete_msg)
      end
    end
  end

  ## Server Callbacks

  def init(retry_after: retry_after, max_attempts: max_attempts) do
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
    sock = connect_retry(hostname, port,
                                 attempt: 1, retry_after: retry_after, max_attempts: max_attempts)
    "OK MPD" <> _ = recv_until_newline(sock)
    if password do
      :ok = :gen_tcp.send(sock, "password #{password}\n")
      :ok = ok_from_socket(sock)
    end
    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: :once)
    {:ok, sock}
  end


  defp connect_retry(hostname, port, attempt: attempt,
                                     retry_after: retry_after,
                                     max_attempts: max_attempts) do
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
                      attempt: attempt + 1, retry_after: retry_after, max_attempts: max_attempts)
    end
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


  defp process_idle_message(msg), do:
    process_idle_message(msg, [])
  defp process_idle_message("changed: database\n" <> rest, events), do:
    process_idle_message(rest, [:database_changed | events])
  defp process_idle_message("changed: update\n" <> rest, events), do:
    process_idle_message(rest, [:update_changed | events])
  defp process_idle_message("changed: stored_playlist\n" <> rest, events), do:
    process_idle_message(rest, [:stored_playlist_changed | events])
  defp process_idle_message("changed: playlist\n" <> rest, events), do:
    process_idle_message(rest, [:playlist_changed | events])
  defp process_idle_message("changed: player\n" <> rest, events), do:
    process_idle_message(rest, [:player_changed | events])
  defp process_idle_message("changed: mixer\n" <> rest, events), do:
    process_idle_message(rest, [:mixer_changed | events])
  defp process_idle_message("changed: output\n" <> rest, events), do:
    process_idle_message(rest, [:outputs_changed | events])
  defp process_idle_message("changed: options\n" <> rest, events), do:
    process_idle_message(rest, [:options_changed | events])
  defp process_idle_message("changed: sticker\n" <> rest, events), do:
    process_idle_message(rest, [:sticker_changed | events])
  defp process_idle_message("changed: subscription\n" <> rest, events), do:
    process_idle_message(rest, [:subscription_changed | events])
  defp process_idle_message("changed: message\n" <> rest, events), do:
    process_idle_message(rest, [:message_changed | events])
  defp process_idle_message("OK\n", events), do:
    events

  def handle_call({:send_and_ack, msg}, _from, sock) do
    :ok = :inet.setopts(sock, active: false)
    :ok = :gen_tcp.send(sock, "noidle\n")
    # check if MPD still has 'idle' events in the queue
    case recv_until_ok(sock) do
      {:ok, ""} ->
        :ok
      {:ok, idle_message} ->
        events = process_idle_message(idle_message <> "OK\n")
        GenServer.cast(Paracusia.PlayerState, {:events, events})
    end
    :ok = :gen_tcp.send(sock, msg)
    :ok = ok_from_socket(sock)
    :ok = :inet.setopts(sock, active: :once)
    :ok = :gen_tcp.send(sock, "idle\n")
    {:reply, :ok, sock}
  end

  def handle_call({:send_and_recv, msg}, _from, sock) do
    :ok = :inet.setopts(sock, active: false)
    :ok = :gen_tcp.send(sock, "noidle\n")
    # check if MPD still has 'idle' events in the queue
    case recv_until_ok(sock) do
      {:ok, ""} ->
        :ok
      {:ok, idle_message} ->
        events = process_idle_message(idle_message <> "OK\n")
        GenServer.cast(Paracusia.PlayerState, {:events, events})
    end
    :ok = :gen_tcp.send(sock, msg)
    reply = recv_until_ok(sock)
    :ok = :inet.setopts(sock, active: :once)
    :ok = :gen_tcp.send(sock, "idle\n")
    {:reply, reply, sock}
  end

  def handle_call(:kill, _from, sock) do
    :ok = :gen_tcp.send(sock, "noidle\nkill\n")
    {:reply, :ok, sock}
  end

  def handle_info({:tcp, _, msg}, sock) do
    complete_msg =
      if String.ends_with?(msg, "OK\n") do
        msg
      else
        case recv_until_ok(sock, msg) do
          {:ok, without_trailing_ok} -> without_trailing_ok <> "OK\n"
        end
      end
    Logger.debug "idle message: #{complete_msg}"
    events = process_idle_message(complete_msg)
    GenServer.cast(Paracusia.PlayerState, {:events, events})
    # We have received this message as a result of having sent idle. We need to resend idle
    # each time after we have obtained a new idle message.
    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: :once)
    {:noreply, sock}
  end

  def terminate(:shutdown, sock) do
    _ = Logger.debug "Teardown connection."
    :ok = :gen_tcp.send(sock, "close\n")
    :ok = :gen_tcp.close(sock)
    :ok
  end


end
