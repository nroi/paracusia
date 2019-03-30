defmodule Paracusia.MpdClient.StatusTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Status

  setup_all do
    {:ok, _} = Paracusia.Mock.start_link()
    :ok = Application.start(:paracusia)

    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "current_song should return a map describing the current song" do
    {:ok, result} = Status.current_song()

    expected = %{
      "file" => "flac/rammstein_-_mutter_(2001)/11._rammstein__nebel.flac",
      "Last-Modified" => "2016-10-08T09:52:35Z",
      "Genre" => "Industrial",
      "Title" => "Nebel",
      "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "Date" => "2001",
      "Disc" => "1",
      "MUSICBRAINZ_RELEASETRACKID" => "141caa1f-6e5f-3c47-b94b-8bcf31bdc85f",
      "AlbumArtistSort" => "Rammstein",
      "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
      "AlbumArtist" => "Rammstein",
      "Album" => "Mutter",
      "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "Artist" => "Rammstein",
      "MUSICBRAINZ_TRACKID" => "bdf0d76e-16f8-4c7b-a94a-121df981ae7a",
      "ArtistSort" => "Rammstein",
      "Track" => "11",
      "Time" => "633",
      "Pos" => "23",
      "Id" => "59"
    }

    assert result == expected
  end

  test "stats should return a map containing statistics" do
    {:ok, result} = Status.stats()

    expected = %Paracusia.PlayerState.Stats{
      uptime: 316_988,
      playtime: 34195,
      artists: 11,
      albums: 29,
      songs: 268,
      db_playtime: 86248,
      db_update: 1_476_811_334
    }

    assert result == expected
  end
end
