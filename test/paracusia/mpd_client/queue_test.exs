defmodule Paracusia.MpdClient.QueueTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Queue

  setup_all do
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)

    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "add_id should return the id of the added song" do
    {:ok, id1} = Queue.add_id("flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac", 0)
    {:ok, id2} = Queue.add_id("flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac")
    assert is_number(id1)
    assert is_number(id2)
  end

  test "find should return a list of all matching songs" do
    {:ok, result} = Queue.find(albumartist: "Rammstein", album: "Mutter", title: "Mutter")

    assert result == [
             %{
               "Album" => "Mutter",
               "AlbumArtist" => "Rammstein",
               "AlbumArtistSort" => "Rammstein",
               "Artist" => "Rammstein",
               "ArtistSort" => "Rammstein",
               "Date" => "2001",
               "Disc" => "1",
               "Genre" => "Industrial",
               "Last-Modified" => "2016-10-08T09:52:53Z",
               "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
               "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
               "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
               "MUSICBRAINZ_RELEASETRACKID" => "df688ae3-10db-386c-b4e5-152f2ed99075",
               "MUSICBRAINZ_TRACKID" => "0629a5b8-ee13-4ae2-bff8-cc337d8fb28d",
               "Time" => "273",
               "Title" => "Mutter",
               "Track" => "6",
               "file" => "flac/rammstein_-_mutter_(2001)/06._rammstein__mutter.flac"
             }
           ]
  end

  test "songs_info_* should return a map or list of maps" do
    {:ok, result1} = Queue.song_info_from_id(0)
    {:ok, [result2 | _]} = Queue.songs_info()
    {:ok, result3} = Queue.song_info_from_pos(0)
    {:ok, [result4 | _]} = Queue.songs_info_from_range({0, 2})

    expected = %{
      "Album" => "Mutter",
      "AlbumArtist" => "Rammstein",
      "AlbumArtistSort" => "Rammstein",
      "Artist" => "Rammstein",
      "ArtistSort" => "Rammstein",
      "Date" => "2001",
      "Disc" => "1",
      "Genre" => "Industrial",
      "Id" => "13",
      "Last-Modified" => "2016-10-08T09:52:40Z",
      "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
      "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_RELEASETRACKID" => "69f8b335-e10b-3050-80ad-2cfe4c0c11b7",
      "MUSICBRAINZ_TRACKID" => "294bfe12-b9f8-4e2d-8e71-97625babd50a",
      "Pos" => "1",
      "Time" => "217",
      "Title" => "Links 2-3-4",
      "Track" => "2",
      "file" => "flac/rammstein_-_mutter_(2001)/02._rammstein__links_2_3_4.flac"
    }

    assert result1 == expected
    assert result2 == expected
    assert result3 == expected
    assert result4 == expected
  end

  test "playlistsearch and changed_since should return a list of maps" do
    {:ok, [result1 | _]} = Queue.search(albumartist: "Rammstein", album: "Mutter")
    {:ok, [result2 | _]} = Queue.changed_since(2)

    expected = %{
      "Album" => "Mutter",
      "AlbumArtist" => "Rammstein",
      "AlbumArtistSort" => "Rammstein",
      "Artist" => "Rammstein",
      "ArtistSort" => "Rammstein",
      "Date" => "2001",
      "Disc" => "1",
      "Genre" => "Industrial",
      "Last-Modified" => "2016-10-08T09:52:44Z",
      "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
      "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "MUSICBRAINZ_RELEASETRACKID" => "91a75b95-be66-3884-84fe-aeef071d9d6c",
      "MUSICBRAINZ_TRACKID" => "3fad33de-9748-4b97-9506-3c1ab2f67529",
      "Time" => "280",
      "Title" => "Mein Herz brennt",
      "Track" => "1",
      "file" => "flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac"
    }

    assert result1 == expected
    assert result2 == expected
  end

  test "changed_since_pos_id" do
    {:ok, result} = Queue.changed_since_pos_id(0)

    expected = [
      %{"Id" => "1", "cpos" => "0"},
      %{"Id" => "2", "cpos" => "1"},
      %{"Id" => "3", "cpos" => "2"}
    ]

    assert result == expected
  end

  test "commands that do not return a message should return :ok" do
    :ok = Queue.add("flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac")
    :ok = Queue.clear()
    :ok = Queue.delete_pos(0)
    :ok = Queue.delete_range({0, 1})
    :ok = Queue.delete_id(0)
    :ok = Queue.move(0, 1)
    :ok = Queue.move({0, 2}, 3)
    :ok = Queue.move_id(0, 1)
    :ok = Queue.set_priority(0, {0, 3})
    :ok = Queue.set_priority_from_id(0, 0)
    :ok = Queue.set_priority_from_id(0, [0, 1, 2, 3])
    :ok = Queue.range_id(0, 30, 60)
    :ok = Queue.remove_range(0)
    :ok = Queue.shuffle()
    :ok = Queue.shuffle({0, 3})
    :ok = Queue.swap(0, 1)
    :ok = Queue.swap_id(0, 1)
    :ok = Queue.add_tag_id(0, :author, "Rammstein")
    :ok = Queue.clear_tag_id(0, :author)
    :ok = Queue.clear_all_tags(0)
  end
end
