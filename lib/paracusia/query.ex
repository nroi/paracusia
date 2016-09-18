defmodule Paracusia.Query do
  alias Paracusia.MpdClient
  defstruct artist: "artist",
            artistsort: "artistsort",
            album: "album",
            albumsort: "albumsort",
            albumartist: "albumartist",
            albumartistsort: "albumartistsort",
            title: "title",
            track: "track",
            name: "name",
            genre: "genre",
            date: "date",
            composer: "composer",
            performer: "performer",
            comment: "comment",
            disc: "disc",
            musicbrainz_artistid: "musicbrainz_artistid",
            musicbrainz_albumid: "musicbrainz_albumid",
            musicbrainz_albumartistid: "musicbrainz_albumartistid",
            musicbrainz_trackid: "musicbrainz_trackid",
            musicbrainz_releasetrackid: "musicbrainz_releasetrackid"

  def merge_tags(tags = [{tag, wanted}|rest], acc) do
    if Map.has_key?(%Paracusia.Query{}, tag) do
      prop = Map.get(%Paracusia.Query{}, tag)
      merge_tags(rest, acc <> "#{prop} \"#{wanted}\" ")
    else
      {tags, acc}
    end
  end
  def merge_tags(unmatched, acc), do: {unmatched, acc}

  def merge_find(x, acc) do
    case merge_tags(x, acc) do
      {[], result} -> result
      {[{:any, wanted}|rest], partial_result} ->
        merge_find(rest, partial_result <> "any \"#{wanted}\" ")
      {[{:file, wanted}|rest], partial_result} ->
        merge_find(rest, partial_result <> "file \"#{wanted}\" ")
      {[{:base, wanted}|rest], partial_result} ->
        merge_find(rest, partial_result <> "base \"#{wanted}\" ")
      # TODO we should mention somewhere that MPD is using modified-since, but we need the user to
      # type modified_since (underscore) since we're using atoms.
      {[{:modified_since, wanted}|rest], partial_result} ->
        merge_find(rest, partial_result <> "modified-since \"#{wanted}\" ")
    end
  end

  def merge_count(x, acc) do
    case merge_tags(x, acc) do
      {[], result} -> result
      {[{:group, :artist}|[]], partial_result} ->
        partial_result <> "group artist"
    end
  end

  defmacro query({:find, _, [keyval]}) do
    quote do
      query_string =
        Paracusia.Query.merge_find(unquote(keyval), "")
        |> String.replace_suffix(" ", "")
      MpdClient.find(query_string)
    end
  end

  defmacro query({:findadd, _, [keyval]}) do
    quote do
      query_string =
        # "Parameters have the same meaning as for find." (MPD protocol spec)
        Paracusia.Query.merge_find(unquote(keyval), "")
        |> String.replace_suffix(" ", "")
      MpdClient.findadd(query_string)
    end
  end

  defmacro query({:count, _, [keyval]}) do
    quote do
      query_string =
        Paracusia.Query.merge_count(unquote(keyval), "")
        |> String.replace_suffix(" ", "")
      MpdClient.count(query_string)
    end
  end

end
