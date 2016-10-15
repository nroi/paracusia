defmodule Paracusia.MpdClient.ReflectionTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Reflection

  setup_all do
    Application.stop(:paracusia)
    port = Application.get_env(:paracusia, :test_port)
    System.put_env("MPD_HOST", "localhost")
    System.put_env("MPD_PORT", "#{port}")
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "Reflection.permitted_commands should yield a list of commands" do
    {:ok, result} = Paracusia.MpdClient.Reflection.permitted_commands
    expected = ["add", "addid", "addtagid", "channels", "clear", "clearerror", "cleartagid",
                "close", "commands", "config", "consume", "count", "crossfade", "currentsong",
                "decoders", "delete", "deleteid", "disableoutput", "enableoutput", "find",
                "findadd", "idle", "kill", "list", "listall", "listallinfo", "listfiles",
                "listmounts", "listplaylist", "listplaylistinfo", "listplaylists", "load", "lsinfo",
                "mixrampdb", "mixrampdelay", "mount", "move", "moveid", "next", "notcommands",
                "outputs", "password", "pause", "ping", "play", "playid", "playlist",
                "playlistadd", "playlistclear", "playlistdelete", "playlistfind", "playlistid",
                "playlistinfo", "playlistmove", "playlistsearch", "plchanges", "plchangesposid",
                "previous", "prio", "prioid", "random", "rangeid", "readcomments", "readmessages",
                "rename", "repeat", "replay_gain_mode", "replay_gain_status", "rescan", "rm",
                "save", "search", "searchadd", "searchaddpl", "seek", "seekcur", "seekid",
                "sendmessage", "setvol", "shuffle", "single", "stats", "status", "sticker", "stop",
                "subscribe", "swap", "swapid", "tagtypes", "toggleoutput", "unmount", "unsubscribe",
                "update", "urlhandlers", "volume"]
    assert result == expected
  end

  test "Reflection.forbidden_commands should yield a list of commands" do
    {:ok, result} = Reflection.forbidden_commands
    assert result == []
  end

  test "Reflection.tagtypes should yield a list of tags" do
    expected = ["Artist", "ArtistSort", "Album", "AlbumSort", "AlbumArtist", "AlbumArtistSort",
                "Title", "Track", "Name", "Genre", "Date", "Composer", "Performer", "Disc",
                "MUSICBRAINZ_ARTISTID", "MUSICBRAINZ_ALBUMID", "MUSICBRAINZ_ALBUMARTISTID",
                "MUSICBRAINZ_TRACKID", "MUSICBRAINZ_RELEASETRACKID"]
    {:ok, result} = Reflection.tag_types
    assert result == expected
  end

  test "Reflection.url_handlers should yield a list of url handlers" do
    expected = ["http://", "https://", "mms://", "mmsh://", "mmst://", "mmsu://", "gopher://",
                "rtp://", "rtsp://", "rtmp://", "rtmpt://", "rtmps://", "smb://", "nfs://",
                "cdda://", "alsa://"]
    {:ok, result} = Reflection.url_handlers
    assert result == expected
  end

  test "Reflection.decoders should yield a map containing all decoders" do
    expected = %{
      "mad" => %{
        suffixes: ["mp3", "mp2"],
        mime_types: ["audio/mpeg"]},
      "vorbis" => %{
        suffixes: ["ogg", "oga"],
        mime_types: ["application/ogg", "application/x-ogg", "audio/ogg", "audio/vorbis",
                   "audio/vorbis+ogg", "audio/x-ogg", "audio/x-vorbis", "audio/x-vorbis+ogg"]},
      "oggflac" =>  %{
        suffixes: ["ogg", "oga"],
        mime_types: ["application/ogg", "application/x-ogg", "audio/ogg", "audio/x-flac+ogg",
                     "audio/x-ogg"]},
      "flac" => %{
        suffixes: ["flac"],
        mime_types: ["application/flac", "application/x-flac", "audio/flac", "audio/x-flac"]}
    }
    {:ok, result} = Reflection.decoders
    assert result == expected
  end


  def teardown() do
    :ok = Application.stop(:paracusia)
  end

end
