defmodule Paracusia.Mock do
  use GenServer

  def start() do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    send self(), :init
    {:ok, nil}
  end

  def handle_info(:init, nil) do
    port = Application.get_env(:paracusia, :test_port)
    {:ok, lsock} = :gen_tcp.listen(port,
                         [:binary, active: true, reuseaddr: true, packet: :line])
    {:ok, sock} = :gen_tcp.accept(lsock)
    :gen_tcp.send(sock, "OK MPD 0.19.0\n")
    {:noreply, {sock, :init, ""}}
  end


  def handle_info({:tcp, _, "commands\n"}, state = {sock, :post_init}) do
    reply = File.read!("test/support/replies/commands")
    :ok = :gen_tcp.send(sock, reply)
    {:noreply, state}
  end

  def handle_info({:tcp, _, msg}, {sock, :init, prev_msg}) do
    case parse_initial(msg, prev_msg) do
      :ok ->
        :gen_tcp.send(sock, "OK\n")
        {:noreply, {sock, :post_init}}
      {:wait, new_msg} ->
        {:noreply, {sock, :init, new_msg}}
    end
  end

  # just ignore idle and noidle commands -- we do not attempt to emulate MPD, we just want to check
  # if replies sent by MPD are parsed correctly by Paracusia.
  def handle_info({:tcp, _, "idle\n"}, state = {_sock, :post_init}) do
    {:noreply, state}
  end
  def handle_info({:tcp, _, "noidle\n"}, state = {sock, :post_init}) do
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end
  def handle_info({:tcp, _, "idle\nnoidle\n"}, state = {sock, :post_init}) do
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _, "notcommands\n"}, state = {sock, :post_init}) do
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _, "disableoutput " <> rest}, state = {sock, :post_init}) do
    {_id, "\n"} = Integer.parse(rest)
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _, "enableoutput " <> rest}, state = {sock, :post_init}) do
    {_id, "\n"} = Integer.parse(rest)
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _, "toggleoutput " <> rest}, state = {sock, :post_init}) do
    {_id, "\n"} = Integer.parse(rest)
    :gen_tcp.send(sock, "OK\n")
    {:noreply, state}
  end

  def handle_info({:tcp, _, "close\n"}, {sock, :post_init}) do
    :ok = :gen_tcp.close(sock)
    {:stop, :normal, nil}
  end


  def handle_info({:tcp, _, msg}, state = {sock, :post_init}) do
    basename = msg |> String.replace_suffix("\n", "")
    reply = File.read!("test/support/replies/#{basename}")
    :ok = :gen_tcp.send(sock, reply)
    {:noreply, state}
  end

  defp parse_initial(msg, prev_msg) do
    # Paracusia initially sends "idle\n" followed by "noidle\n. We just ignore these messages and
    # wait for the actuall command to arrive.
    if prev_msg <> msg == "idle\nnoidle\n" do
      :ok
    else
      {:wait, prev_msg <> msg}
    end
  end


end
