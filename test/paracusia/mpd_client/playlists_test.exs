defmodule Paracusia.MpdClient.PlaylistsTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Playlists

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


  test "list should return the songs in a given playlist" do
    {:ok, result} = Playlists.list("Mutter by Rammstein")
    expected =  ["flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac",
                 "flac/rammstein_-_mutter_(2001)/02._rammstein__links_2_3_4.flac",
                 "flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac",
                 "flac/rammstein_-_mutter_(2001)/04._rammstein__ich_will.flac",
                 "flac/rammstein_-_mutter_(2001)/05._rammstein__feuer_frei!.flac",
                 "flac/rammstein_-_mutter_(2001)/06._rammstein__mutter.flac",
                 "flac/rammstein_-_mutter_(2001)/07._rammstein__spieluhr.flac",
                 "flac/rammstein_-_mutter_(2001)/08._rammstein__zwitter.flac",
                 "flac/rammstein_-_mutter_(2001)/09._rammstein__rein_raus.flac",
                 "flac/rammstein_-_mutter_(2001)/10._rammstein__adios.flac",
                 "flac/rammstein_-_mutter_(2001)/11._rammstein__nebel.flac",
                 "flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac",
                 "flac/rammstein_-_mutter_(2001)/02._rammstein__links_2_3_4.flac",
                 "flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac",
                 "flac/rammstein_-_mutter_(2001)/04._rammstein__ich_will.flac",
                 "flac/rammstein_-_mutter_(2001)/05._rammstein__feuer_frei!.flac",
                 "flac/rammstein_-_mutter_(2001)/06._rammstein__mutter.flac",
                 "flac/rammstein_-_mutter_(2001)/07._rammstein__spieluhr.flac",
                 "flac/rammstein_-_mutter_(2001)/08._rammstein__zwitter.flac",
                 "flac/rammstein_-_mutter_(2001)/09._rammstein__rein_raus.flac",
                 "flac/rammstein_-_mutter_(2001)/10._rammstein__adios.flac",
                 "flac/rammstein_-_mutter_(2001)/11._rammstein__nebel.flac"]
    assert result == expected
  end

  test "list_info should return the metadata about a playlist" do
    {:ok, [first|_]} = Paracusia.MpdClient.Playlists.list_info("Mutter by Rammstein")
    expected = %{"Album" => "Mutter", "AlbumArtist" => "Rammstein",
      "AlbumArtistSort" => "Rammstein", "Artist" => "Rammstein",
      "ArtistSort" => "Rammstein", "Date" => "2001", "Disc" => "1",
      "Genre" => "Industrial", "Last-Modified" => "2016-10-08T09:52:44Z",
      "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
      "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_RELEASETRACKID" => "91a75b95-be66-3884-84fe-aeef071d9d6c",
      "MUSICBRAINZ_TRACKID" => "3fad33de-9748-4b97-9506-3c1ab2f67529",
      "Time" => "280", "Title" => "Mein Herz brennt", "Track" => "1",
      "file" => "flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac"}
    assert first == expected
  end

  test "list_playlists should return a list of playlists" do
    {:ok, result} = Playlists.list_all
    expected = [
      %{"Last-Modified" => "2016-10-09T14:09:39Z", "playlist" => "Best Rated"},
      %{"Last-Modified" => "2016-10-08T13:34:22Z", "playlist" => "Mutter by Rammstein"}]
    assert result == expected
  end

  test "commands that do not return a message should return :ok" do
    :ok = Playlists.load("Mutter by Rammstein")
    :ok = Playlists.load("Mutter by Rammstein", {1, 3})
    :ok = Playlists.add("Mutter by Rammstein",
                        "flac/rammstein_-_mutter_\(2001\)/03._rammstein__sonne.flac")
    :ok = Playlists.clear("Mutter by Rammstein")
    :ok = Playlists.delete_pos("Mutter by Rammstein", 0)
    :ok = Playlists.move("Mutter by Rammstein", 0, 1)
    :ok = Playlists.rename("Mutter by Rammstein", "Rammstein - Mutter")
    :ok = Playlists.remove("Rammstein - Mutter")
    :ok = Playlists.save("my playlist")
  end


end
