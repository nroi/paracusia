defmodule Paracusia.MpdClient do
  defstruct sock: nil,
            prev_msg: "",
            status: :idle,
            # contains the PIDs of processes that called send_and_recv/1
            queue: []

  use GenServer
  @moduledoc false
  require Logger
  alias Paracusia.MpdClient

  # MpdClient is always in one of the following states:
  #   - idle: when we expect all messages from MPD to be an idle response, or an acknowledgement of
  #       having sent noidle (i.e., "OK\n")
  #   - non_idle: while waiting for regular messages from MPD.

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_and_recv(msg) do
    GenServer.cast(__MODULE__, {:send_and_recv, msg, self()})

    receive do
      {:complete_msg, {:ok, msg}} -> {:ok, msg}
      {:complete_msg, {:error, msg}} -> error_message_to_error(msg)
    after
      300 ->
        raise "Timeout"
    end
  end

  def send_and_ack(msg) do
    GenServer.cast(__MODULE__, {:send_and_recv, msg, self()})

    receive do
      {:complete_msg, {:ok, ""}} -> :ok
      {:complete_msg, {:error, msg}} -> error_message_to_error(msg)
    after
      300 ->
        raise "Timeout"
    end
  end

  defp error_message_to_error(msg) do
    case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, msg, capture: :all_but_first) do
      [errorcode, command, message] ->
        {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
    end
  end

  def init(retry_after: retry_after, max_attempts: max_attempts) do
    # to close mpd connection after application stop
    :erlang.process_flag(:trap_exit, true)

    hostname_app =
      case Application.get_env(:paracusia, :hostname) do
        nil -> nil
        hostname -> to_charlist(hostname)
      end

    port_app = Application.get_env(:paracusia, :port)
    password_app = Application.get_env(:paracusia, :password)

    {hostname_env, password_env} =
      case System.get_env("MPD_HOST") do
        nil ->
          {nil, nil}

        hostname ->
          case String.split(hostname, "@") do
            [host] -> {host, nil}
            [password, h] -> {to_charlist(h), password}
          end
      end

    port_env = System.get_env("MPD_PORT")
    use_app_config = !!(hostname_app || port_app || password_app)

    {hostname, port, password} =
      case use_app_config do
        true ->
          {hostname_app, port_app || 6600, password_app}

        false ->
          port = (port_env && String.to_integer(port_env)) || 6600
          {hostname_env, port, password_env}
      end

    # When the GenServer is restarted as a result of the MPD server restarting (and therefore
    # closing its connection to Paracusia), connecting to MPD may fail if MPD takes longer to
    # restart than Paracusia. For that reason, we retry connection establishment.
    ip_addrs = ip_addresses(hostname)
    if ip_addrs == [], do: raise("Unable to resolve IP address for hostname #{inspect(hostname)}")
    sock = connect_retry(ip_addresses(hostname), port, 1, 0, retry_after, max_attempts)
    {:ok, "OK MPD" <> _} = :gen_tcp.recv(sock, 0)

    _ =
      if password do
        :ok = :gen_tcp.send(sock, "password #{password}\n")
        {:ok, "OK\n"} = :gen_tcp.recv(sock, 0)
      end

    :ok = :gen_tcp.send(sock, "idle\n")
    :ok = :inet.setopts(sock, active: true)
    {:ok, %MpdClient{sock: sock}}
  end

  # Given a host name (which may also be an IPv4, an IPv6 address or a file name), return a list of
  # {address_family, ip_address} tuples.
  defp ip_addresses(hostname) do
    hostname = to_charlist(hostname)

    if socket?(hostname) do
      [{:local, hostname}]
    else
      ipv6 = {:inet6, :inet.getaddr(hostname, :inet6)}
      ipv4 = {:inet, :inet.getaddr(hostname, :inet)}
      for {family, {:ok, address}} <- [ipv6, ipv4], do: {family, address}
    end
  end

  defp ip_string(:inet, ip), do: :inet.ntoa(ip)
  defp ip_string(:inet6, ip), do: :inet.ntoa(ip)
  defp ip_string(:local, ip), do: ip

  defp socket?(hostname) do
    case File.stat(hostname) do
      {:ok, %File.Stat{type: :other}} -> true
      _ -> false
    end
  end

  defp connect_retry(addrs, port, attempt, addr_idx, retry_after, max_attempts) do
    if attempt > max_attempts do
      reason = "Connection establishment failed, maximum number of connection attempts exceeded."
      _ = Logger.error(reason)
      raise reason
    end

    {addr_family, hostname} = Enum.at(addrs, addr_idx)
    next_addr_idx = rem(addr_idx + 1, Enum.count(addrs))
    opts = [:binary, addr_family, active: false, packet: :line, nodelay: true]

    {hostname_conn, port_conn} =
      case addr_family do
        :local -> {{:local, hostname}, 0}
        _ -> {hostname, port}
      end

    target_description = "#{ip_string(addr_family, hostname)}:#{port_conn} (#{addr_family})"

    case :gen_tcp.connect(hostname_conn, port_conn, opts) do
      {:ok, sock} ->
        _ = Logger.debug("Successfully connected to #{target_description}")
        sock

      {:error, :econnrefused} when next_addr_idx == 0 ->
        _ = Logger.error("Connection to #{target_description} refused, retry after #{retry_after} ms.")
        :timer.sleep(retry_after)
        connect_retry(addrs, port, attempt + 1, next_addr_idx, retry_after, max_attempts)

      {:error, :econnrefused} when next_addr_idx >= 0 ->
        {_, next_hostname} = Enum.at(addrs, next_addr_idx)

        _ =
          Logger.warn(
            "Connection refused for #{target_description}, " <>
              "trying #{ip_string(addr_family, next_hostname)} instead."
          )

        connect_retry(addrs, port, attempt, next_addr_idx, retry_after, max_attempts)
    end
  end

  def handle_cast({:send_and_recv, msg, sender}, state = %MpdClient{sock: sock, queue: queue}) do
    :ok = :gen_tcp.send(sock, "noidle\n#{msg}idle\n")
    # Note that the current state remains at 'idle': the next answer still needs to be interpreted
    # as the answer to the 'idle' command!
    {:noreply, %{state | queue: :lists.append(queue, [sender])}}
  end

  # Caution: we need to consider the case when the user wants to send the message while we still
  # haven't gotten the entire idle message.
  def handle_info({:tcp, _, "changed: database\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :database_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: update\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :update_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: stored_playlist\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :stored_playlist_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: playlist\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :playlist_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: player\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :player_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: mixer\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :mixer_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: output\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :outputs_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: options\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :options_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: sticker\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :sticker_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: subscription\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :subscription_changed})
    {:noreply, state}
  end

  def handle_info({:tcp, _, "changed: message\n"}, state = %MpdClient{status: :idle}) do
    :ok = GenServer.cast(Paracusia.PlayerState, {:event, :message_changed})
    {:noreply, state}
  end

  def handle_info(
        {:tcp, _, "OK\n"},
        state = %MpdClient{sock: sock, prev_msg: "", status: :idle, queue: []}
      ) do
    :ok = :gen_tcp.send(sock, "idle\n")
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    _ = Logger.warn("TCP connection closed by server.")
    {:stop, :disconnect_by_server, state}
  end

  def handle_info(
        {:tcp, _, "OK\n"},
        state = %MpdClient{prev_msg: "", status: :idle, queue: [_ | _]}
      ) do
    # if queue != [], we have already sent "noidle\nmsg\nidle\n, hence, no new idle message
    # needs to be sent.
    {:noreply, %{state | status: :non_idle}}
  end

  def handle_info(
        {:tcp, _, "OK\n"},
        state = %MpdClient{prev_msg: prev_msg, status: :non_idle, queue: [recipient | rest]}
      ) do
    send(recipient, {:complete_msg, {:ok, prev_msg}})
    {:noreply, %{state | status: :idle, prev_msg: "", queue: rest}}
  end

  def handle_info(
        {:tcp, _, recvd = "ACK " <> _},
        state = %MpdClient{prev_msg: "", status: :non_idle, queue: [recipient | rest]}
      ) do
    if !String.ends_with?(recvd, "\n") do
      raise "Expected to receive an entire line, got instead: #{recvd}"
    end

    send(recipient, {:complete_msg, {:error, recvd}})
    {:noreply, %{state | status: :idle, prev_msg: "", queue: rest}}
  end

  def handle_info(
        {:tcp, _, partial_msg},
        state = %MpdClient{status: :non_idle, prev_msg: prev_msg}
      ) do
    {:noreply, %{state | prev_msg: prev_msg <> partial_msg}}
  end

  def handle_call(:kill, _from, sock) do
    :ok = :gen_tcp.send(sock, "noidle\nkill\n")
    {:reply, :ok, sock}
  end

  def terminate(:shutdown, %MpdClient{sock: sock}) do
    _ = Logger.debug("Teardown connection.")
    :ok = :gen_tcp.send(sock, "close\n")
    :ok = :gen_tcp.close(sock)
    :ok
  end

  def terminate(:disconnect_by_server, %MpdClient{sock: sock}) do
    :ok = :gen_tcp.close(sock)
    :ok
  end
end
