defmodule Paracusia.MpdClient.DatabaseTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Database

  setup_all do
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "count should return the number of songs and the playtime" do
    {:ok, result} = Database.count(albumartist: "Rammstein", album: "Mutter")
    assert result == %{"playtime" => 3048, "songs" => 11}
  end

  test "count_grouped should return the results grouped by the given parameter" do
    {:ok, result} = Database.count_grouped(:album, albumartist: "Rammstein")
    expected = [
      %{"Album" => "Mutter",
        "songs" => 11,
        "playtime" => 3048},
      %{"Album" => "Reise, Reise",
        "songs" => 14,
        "playtime" => 3385},
      %{"Album" => "Rosenrot",
        "songs" => 11,
        "playtime" => 2886},
      %{"Album" => "Sehnsucht",
        "songs" => 13,
        "playtime" => 3138}]
    assert result == expected
  end

  test "find and search should return a list of maps that match the given filters" do
    {:ok, result1} = Database.find(albumartist: "Rammstein", album: "Mutter")
    {:ok, result2} = Database.search(albumartist: "Rammstein", album: "Mutter")
    [first1 | _] = result1
    [first2 | _] = result2
    expected = %{"Album" => "Mutter",
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
                 "Time" => "280", "Title" => "Mein Herz brennt", "Track" => "1",
                 "file" => "flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac"}
    assert first1 == expected
    assert first2 == expected
  end

  test "findadd/searchadd should return :ok" do
    :ok = Database.find_add(albumartist: "Rammstein")
    :ok = Database.search_add(albumartist: "Rammstein")
  end

  test "list should return a list of albums that match the given filters" do
    {:ok, ["Mutter"]} = Database.list(:album, albumartist: "Rammstein", date: 2001)
  end

  test "listall should return the URIs inside the given URI" do
    {:ok, result} = Database.list_all("flac/rammstein_-_mutter_\(2001\)")
    expected = [{"directory", "flac/rammstein_-_mutter_(2001)"},
                {"file", "flac/rammstein_-_mutter_(2001)/01._rammstein__mein_herz_brennt.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/02._rammstein__links_2_3_4.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/04._rammstein__ich_will.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/05._rammstein__feuer_frei!.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/06._rammstein__mutter.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/07._rammstein__spieluhr.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/08._rammstein__zwitter.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/09._rammstein__rein_raus.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/10._rammstein__adios.flac"},
                {"file", "flac/rammstein_-_mutter_(2001)/11._rammstein__nebel.flac"}]
    assert result == expected
  end

  test "list_files should return a list of maps" do
    {:ok, result} = Database.list_files("flac/rammstein_-_mutter_\(2001\)")
    expected = [
      %{"Last-Modified" => "2016-10-08T09:52:20Z",
        "file" => "10._rammstein__adios.flac",
        "size" => "29299771"},
      %{"Last-Modified" => "2016-10-08T09:52:25Z",
        "file" => "08._rammstein__zwitter.flac",
        "size" => "35437237"},
      %{"Last-Modified" => "2016-10-08T09:52:35Z",
        "file" => "11._rammstein__nebel.flac",
        "size" => "66548744"},
      %{"Last-Modified" => "2016-10-08T09:52:40Z",
        "file" => "02._rammstein__links_2_3_4.flac",
        "size" => "29973601"},
      %{"Last-Modified" => "2016-10-08T09:52:44Z",
        "file" => "01._rammstein__mein_herz_brennt.flac",
        "size" => "35367921"},
      %{"Last-Modified" => "2016-10-08T09:52:48Z",
        "file" => "09._rammstein__rein_raus.flac",
        "size" => "26398157"},
      %{"Last-Modified" => "2016-10-08T09:52:53Z",
        "file" => "06._rammstein__mutter.flac",
        "size" => "34528543"},
      %{"Last-Modified" => "2016-10-08T09:52:56Z",
        "file" => "05._rammstein__feuer_frei!.flac",
        "size" => "25752875"},
      %{"Last-Modified" => "2016-10-08T09:53:00Z",
        "file" => "04._rammstein__ich_will.flac",
        "size" => "29588988"},
      %{"Last-Modified" => "2016-10-08T09:53:05Z",
        "file" => "03._rammstein__sonne.flac",
        "size" => "37233007"},
      %{"Last-Modified" => "2016-10-08T09:53:10Z",
        "file" => "07._rammstein__spieluhr.flac",
        "size" => "39516907"}]
    assert result == expected
  end

  test "lsinfo should return the contents of the given directory" do
    {:ok, [first | _]} = Database.lsinfo("flac/rammstein_-_mutter_\(2001\)")
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

  test "read_comments should return a map" do
    uri = "flac/rammstein_-_mutter_\(2001\)/03._rammstein__sonne.flac"
    {:ok, result} = Database.read_comments(uri)
    expected =  %{"ISRC" => "DEN120003766", "ALBUMARTIST" => "Rammstein", "TRACKTOTAL" => "11",
      "ARTIST" => "Rammstein", "MUSICBRAINZ_ALBUMID" => "fe4f8e86-abf4-4a96-b82c-1cadf9a066e1",
      "MUSICBRAINZ_RELEASEGROUPID" => "833a9e1a-62c0-32f6-ab47-7797c4d83b07",
      "TOTALTRACKS" => "11", "MUSICBRAINZ_TRACKID" => "f8030bcd-e6e4-48cb-ba0d-58b3a1132ad4",
      "MUSICBRAINZ_ALBUMARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "ALBUMARTISTSORT" => "Rammstein", "COMMENT" => "EAC FLAC -8", "DATE" => "2001",
      "MUSICBRAINZ_RELEASETRACKID" => "1d8b5e73-dda3-3b3b-a723-0492f30c832b", "TITLE" => "Sonne",
      "SCRIPT" => "Latn", "ALBUM" => "Mutter", "BARCODE" => "731454963923",
      "ARTISTS" => "Rammstein", "RELEASESTATUS" => "official", "TRACKNUMBER" => "3",
      "ORIGINALYEAR" => "2001", "LABEL" => "Motor Music", "DISCNUMBER" => "1",
      "MUSICBRAINZ_ARTISTID" => "b2d122f9-eadb-4930-a196-8f221eeb0c66",
      "RELEASECOUNTRY" => "DE", "ARTISTSORT" => "Rammstein", "CATALOGNUMBER" => "549639-2",
      "RELEASETYPE" => "album", "MEDIA" => "CD", "ORIGINALDATE" => "2001-04-02",
      "GENRE" => "Industrial", "TOTALDISCS" => "1", "DISCTOTAL" => "1"}
    assert result == expected
  end

  test "searchadd/searchaddpl should return :ok" do
    :ok = Database.search_add(albumartist: "Rammstein")
    :ok = Database.search_add_playlist("Mutter by Rammstein",
                                       albumartist: "Rammstein", album: "Mutter")
  end

  test "update and rescan should return {:ok, integer}" do
    {:ok, 1} = Database.update()
    {:ok, 1} = Database.update("flac")
    {:ok, 1} = Database.rescan()
    {:ok, 1} = Database.rescan("flac")
  end
end
