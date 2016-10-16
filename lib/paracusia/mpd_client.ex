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
    with {:ok, m} <- :gen_tcp.recv(sock, 0) do
      complete_answer = prev_answer <> m
      if complete_answer |> String.ends_with?("\n") do
        {:ok, complete_answer}
      else
        recv_until_newline(sock, complete_answer)
      end
    end
  end

  @spec recv_until_ok(port, String.t) :: {:ok, String.t} | MpdTypes.mpd_error
  defp recv_until_ok(sock, prev_answer \\ "") do
    with {:ok, complete_msg} <- recv_until_newline(sock, prev_answer) do
      if complete_msg |> String.ends_with?("OK\n") do
        {:ok, complete_msg |> String.replace_suffix("OK\n", "")}
      else
        case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, capture: :all_but_first) do
          [errorcode, command, message] ->
            {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
          nil ->
            recv_until_ok(sock, complete_msg)
        end
      end
    end
  end

  defp unrecv_from_mailbox(sock) do
    # since we constantly switch between active and passive, it could happen that a message arrives
    # in the mailbox shortly before the socket is switched to passive. To avoid waiting for a messge
    # that will never arrive, we put it back onto the socket.
    receive do
      {:tcp, _, msg = "changed: " <> _} ->
        :inet_tcp.unrecv(sock, msg)
        _ = Logger.debug "The following message has been put back the socket: >#{msg}<"
        unrecv_from_mailbox(sock)
    after 0 ->
        :ok
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
    {:ok, "OK MPD" <> _} = recv_until_newline(sock)
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
    case :gen_tcp.recv(socket, 0) do
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


  defp events_from_idle_msg(msg), do:
    events_from_idle_msg(msg, [])
  defp events_from_idle_msg("changed: database\n" <> rest, events), do:
    events_from_idle_msg(rest, [:database_changed | events])
  defp events_from_idle_msg("changed: update\n" <> rest, events), do:
    events_from_idle_msg(rest, [:update_changed | events])
  defp events_from_idle_msg("changed: stored_playlist\n" <> rest, events), do:
    events_from_idle_msg(rest, [:stored_playlist_changed | events])
  defp events_from_idle_msg("changed: playlist\n" <> rest, events), do:
    events_from_idle_msg(rest, [:playlist_changed | events])
  defp events_from_idle_msg("changed: player\n" <> rest, events), do:
    events_from_idle_msg(rest, [:player_changed | events])
  defp events_from_idle_msg("changed: mixer\n" <> rest, events), do:
    events_from_idle_msg(rest, [:mixer_changed | events])
  defp events_from_idle_msg("changed: output\n" <> rest, events), do:
    events_from_idle_msg(rest, [:outputs_changed | events])
  defp events_from_idle_msg("changed: options\n" <> rest, events), do:
    events_from_idle_msg(rest, [:options_changed | events])
  defp events_from_idle_msg("changed: sticker\n" <> rest, events), do:
    events_from_idle_msg(rest, [:sticker_changed | events])
  defp events_from_idle_msg("changed: subscription\n" <> rest, events), do:
    events_from_idle_msg(rest, [:subscription_changed | events])
  defp events_from_idle_msg("changed: message\n" <> rest, events), do:
    events_from_idle_msg(rest, [:message_changed | events])
  defp events_from_idle_msg("", events), do:
    events

  # Before sending the actual message, we need to:
  #   - send noidle to the socket
  #   - check if there are still 'idle' events left on the socket
  #   - if so, notify the event handlers
  defp prepare_before_send(sock) do
    unrecv_from_mailbox(sock)
    :ok = :gen_tcp.send(sock, "noidle\n")
    # check if MPD still has 'idle' events in the queue. In most cases, events will be [].
    events = case recv_until_ok(sock) do
      {:ok, msg} -> events_from_idle_msg(msg)
    end
    :ok = GenServer.cast(Paracusia.PlayerState, {:events, events})
  end

  def handle_call({:send_and_ack, msg}, _from, sock) do
    :ok = :inet.setopts(sock, active: false)
    :ok = prepare_before_send(sock)
    :ok = :gen_tcp.send(sock, msg)
    {:ok, ""} = recv_until_ok(sock)
    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: :once)
    {:reply, :ok, sock}
  end


  def handle_call({:send_and_recv, msg}, _from, sock) do
    :ok = :inet.setopts(sock, active: false)
    :ok = prepare_before_send(sock)
    :ok = :gen_tcp.send(sock, msg)
    reply = recv_until_ok(sock)
    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: :once)
    {:reply, reply, sock}
  end

  def handle_call(:kill, _from, sock) do
    :ok = :gen_tcp.send(sock, "noidle\nkill\n")
    {:reply, :ok, sock}
  end

  def handle_info({:tcp, _, msg}, sock) do
    :ok = :inet.setopts(sock, active: false)
    unrecv_from_mailbox(sock)
    complete_msg =
      if String.ends_with?(msg, "OK\n") do
        msg |> String.replace_suffix("OK\n", "")
      else
        case recv_until_ok(sock, msg) do
          {:ok, without_trailing_ok} -> without_trailing_ok
        end
      end
    events = events_from_idle_msg(complete_msg)
    # We have received this message as a result of having sent idle. We need to resend idle
    # each time after we have obtained a new idle message.
    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: :once)
    :ok = GenServer.cast(Paracusia.PlayerState, {:events, events})
    {:noreply, sock}
  end

  def terminate(:shutdown, sock) do
    _ = Logger.debug "Teardown connection."
    :ok = :gen_tcp.send(sock, "close\n")
    :ok = :gen_tcp.close(sock)
    :ok
  end


end
