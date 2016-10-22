defmodule Paracusia.Mock do
  use GenServer

  def start() do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    send self(), :init
    {:ok, nil}
  end

  defp answer_from_msg("noidle\n"), do: "OK\n"
  defp answer_from_msg("notcommands\n"), do: "OK\n"
  defp answer_from_msg("disableoutput " <> _), do: "OK\n"
  defp answer_from_msg("enableoutput " <> _), do: "OK\n"
  defp answer_from_msg("toggleoutput " <> _), do: "OK\n"
  defp answer_from_msg("searchadd " <> _), do: "OK\n"
  defp answer_from_msg("searchaddpl " <> _), do: "OK\n"
  defp answer_from_msg("update" <> _), do: "updating_db: 1\nOK\n"
  defp answer_from_msg("rescan" <> _), do: "updating_db: 1\nOK\n"
  defp answer_from_msg("count albumartist \"Rammstein\" album \"Mutter\" \n"), do:
    "songs: 11\nplaytime: 3048\nOK\n"
  defp answer_from_msg("count albumartist \"Rammstein\" group album\n"), do:
    File.read!("test/support/replies/count_grouped")
  defp answer_from_msg("find albumartist \"Rammstein\" album \"Mutter\" \n"), do:
    File.read!("test/support/replies/find")
  defp answer_from_msg("playlistsearch albumartist \"Rammstein\" album \"Mutter\" \n"), do:
    File.read!("test/support/replies/find")
  defp answer_from_msg("plchanges " <> _), do:
    File.read!("test/support/replies/find")
  defp answer_from_msg("plchangesposid " <> _), do:
    "cpos: 0\nId: 1\ncpos: 1\nId: 2\ncpos: 2\nId: 3\nOK\n"
  defp answer_from_msg("search albumartist \"Rammstein\" album \"Mutter\" \n"), do:
    File.read!("test/support/replies/find")
  defp answer_from_msg("playlistfind albumartist \"Rammstein\" album \"Mutter\" title \"Mutter\" \n"), do:
    File.read!("test/support/replies/playlistfind")
  defp answer_from_msg("findadd " <> _), do: "OK\n"
  defp answer_from_msg("list album albumartist \"Rammstein\" date \"2001\" \n"), do:
    "Album: Mutter\nOK\n"
  defp answer_from_msg("listall \"flac/rammstein_-_mutter_\(2001\)\"\n"), do:
    File.read!("test/support/replies/listall")
  defp answer_from_msg("listfiles \"flac/rammstein_-_mutter_\(2001\)\"\n"), do:
    File.read!("test/support/replies/listfiles")
  defp answer_from_msg("lsinfo \"flac/rammstein_-_mutter_\(2001\)\"\n"), do:
    File.read!("test/support/replies/lsinfo")
  defp answer_from_msg("readcomments \"flac/rammstein_-_mutter_\(2001\)/03._rammstein__sonne.flac\"\n"), do:
    File.read!("test/support/replies/readcomments")
  defp answer_from_msg("play\n"), do: "OK\n"
  defp answer_from_msg("play " <> _), do: "OK\n"
  defp answer_from_msg("playid" <> _), do: "OK\n"
  defp answer_from_msg("pause " <> _), do: "OK\n"
  defp answer_from_msg("stop\n"), do: "OK\n"
  defp answer_from_msg("next\n"), do: "OK\n"
  defp answer_from_msg("previous\n"), do: "OK\n"
  defp answer_from_msg("seek" <> _), do: "OK\n"
  defp answer_from_msg("consume" <> _), do: "OK\n"
  defp answer_from_msg("crossfade" <> _), do: "OK\n"
  defp answer_from_msg("mixrampdb" <> _), do: "OK\n"
  defp answer_from_msg("random" <> _), do: "OK\n"
  defp answer_from_msg("repeat" <> _), do: "OK\n"
  defp answer_from_msg("setvol" <> _), do: "OK\n"
  defp answer_from_msg("single" <> _), do: "OK\n"
  defp answer_from_msg("replay_gain_mode" <> _), do: "OK\n"
  defp answer_from_msg("volume " <> _), do: "OK\n"
  defp answer_from_msg("load " <> _), do: "OK\n"
  defp answer_from_msg("replay_gain_status\n" <> _), do: "replay_gain_mode: off\nOK\n"
  defp answer_from_msg("playlistadd " <> _), do: "OK\n"
  defp answer_from_msg("playlistclear" <> _), do: "OK\n"
  defp answer_from_msg("playlistdelete " <> _), do: "OK\n"
  defp answer_from_msg("playlistmove " <> _), do: "OK\n"
  defp answer_from_msg("rename " <> _), do: "OK\n"
  defp answer_from_msg("save " <> _), do: "OK\n"
  defp answer_from_msg("rm " <> _), do: "OK\n"
  defp answer_from_msg("add " <> _), do: "OK\n"
  defp answer_from_msg("addid " <> _), do: "Id: 20\nOK\n"
  defp answer_from_msg("clear\n"), do: "OK\n"
  defp answer_from_msg("delete" <> _), do: "OK\n"
  defp answer_from_msg("move" <> _), do: "OK\n"
  defp answer_from_msg("prio" <> _), do: "OK\n"
  defp answer_from_msg("range" <> _), do: "OK\n"
  defp answer_from_msg("shuffle" <> _), do: "OK\n"
  defp answer_from_msg("swap" <> _), do: "OK\n"
  defp answer_from_msg("addtagid" <> _), do: "OK\n"
  defp answer_from_msg("cleartagid" <> _), do: "OK\n"
  defp answer_from_msg("listplaylist \"Mutter by Rammstein\"\n"), do:
    File.read!("test/support/replies/listplaylist")
  defp answer_from_msg("listplaylistinfo \"Mutter by Rammstein\"\n"), do:
    File.read!("test/support/replies/listplaylistinfo")
  defp answer_from_msg("playlistid" <> _), do:
    File.read!("test/support/replies/playlistid")
  defp answer_from_msg("playlistinfo" <> _), do:
    File.read!("test/support/replies/playlistid")
  defp answer_from_msg(unmatched) do
    basename = unmatched |> String.replace_suffix("\n", "")
    File.read!("test/support/replies/#{basename}")
  end

  def handle_info(:init, nil) do
    port = Application.get_env(:paracusia, :port)
    {:ok, lsock} = :gen_tcp.listen(port,
                         [:binary, active: true, reuseaddr: true, packet: :line])
    {:ok, sock} = :gen_tcp.accept(lsock)
    :gen_tcp.send(sock, "OK MPD 0.19.0\n")
    {:noreply, {sock, :init, ""}}
  end

  def handle_info({:tcp, _, "idle\n"}, state = {_, :post_init}), do: {:noreply, state}

  def handle_info({:tcp, _, "close\n"}, {sock, :post_init}) do
    :ok = :gen_tcp.close(sock)
    {:stop, :normal, nil}
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

  def handle_info({:tcp, _, msg}, state = {sock, :post_init}) do
    answer = answer_from_msg(msg)
    :ok = :gen_tcp.send(sock, answer)
    {:noreply, state}
  end

  defp parse_initial(msg, prev_msg) do
    # Paracusia initially sends "idle\n" followed by "noidle\n. We just ignore these messages and
    # wait for the actual command to arrive.
    if prev_msg <> msg == "idle\nnoidle\n" do
      :ok
    else
      {:wait, prev_msg <> msg}
    end
  end


end
