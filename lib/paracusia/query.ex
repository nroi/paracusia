defmodule Paracusia.Query do
  alias Paracusia.MpdClient

  def merge([]), do: ""
  def merge([{:artist, wantedArtist} | rest]), do:
    "artist \"#{wantedArtist}\" " <> merge(rest)
  def merge([{:artistsort, wanted} | rest]), do:
    "artistsort \"#{wanted}\" " <> merge(rest)
  def merge([{:album, wanted} | rest]), do:
    "album \"#{wanted}\" " <> merge(rest)
  def merge([{:albumsort, wanted} | rest]), do:
    "albumsort \"#{wanted}\" " <> merge(rest)
  def merge([{:albumartist, wanted} | rest]), do:
    "albumartist \"#{wanted}\" " <> merge(rest)
  def merge([{:albumartistsort, wanted} | rest]), do:
    "albumartistsort \"#{wanted}\" " <> merge(rest)
  def merge([{:title, wanted} | rest]), do:
    "title \"#{wanted}\" " <> merge(rest)
  def merge([{:track, wanted} | rest]), do:
    "track \"#{wanted}\" " <> merge(rest)
  def merge([{:name, wanted} | rest]), do:
    "name \"#{wanted}\" " <> merge(rest)
  def merge([{:genre, wanted} | rest]), do:
    "genre \"#{wanted}\" " <> merge(rest)
  def merge([{:date, wanted} | rest]), do:
    "date \"#{wanted}\" " <> merge(rest)
  def merge([{:composer, wanted} | rest]), do:
    "composer \"#{wanted}\" " <> merge(rest)
  def merge([{:performer, wanted} | rest]), do:
    "performer \"#{wanted}\" " <> merge(rest)
  def merge([{:comment, wanted} | rest]), do:
    "comment \"#{wanted}\" " <> merge(rest)
  def merge([{:disc, wanted} | rest]), do:
    "disc \"#{wanted}\" " <> merge(rest)
  def merge([{:musicbrainz_artistid, wanted} | rest]), do:
    "musicbrainz_artistid \"#{wanted}\" " <> merge(rest)
  def merge([{:musicbrainz_albumid, wanted} | rest]), do:
    "musicbrainz_albumid \"#{wanted}\" " <> merge(rest)
  def merge([{:musicbrainz_albumartistid, wanted} | rest]), do:
    "musicbrainz_albumartistid \"#{wanted}\" " <> merge(rest)
  def merge([{:musicbrainz_trackid, wanted} | rest]), do:
    "musicbrainz_trackid \"#{wanted}\" " <> merge(rest)
  def merge([{:musicbrainz_releasetrackid, wanted} | rest]), do:
    "musicbrainz_releasetrackid \"#{wanted}\" " <> merge(rest)
  def merge([{:any, wanted} | rest]), do:
    "any \"#{wanted}\" " <> merge(rest)
  def merge([{:file, wanted} | rest]), do:
    "file \"#{wanted}\" " <> merge(rest)
  def merge([{:base, wanted} | rest]), do:
    "base \"#{wanted}\" " <> merge(rest)
  # TODO we should mention somewhere that MPD is using modified-since, but we need the user to type
  # modified_since (underscore) since we're using atoms.
  def merge([{:modified_since, wanted} | rest]), do:
    "modified-since \"#{wanted}\" " <> merge(rest)

  defmacro query({:find, _, [keyval]}) do
    quote do
      query_string = Paracusia.Query.merge(unquote keyval) |> String.replace_suffix(" ", "")
      MpdClient.find(query_string)
    end
  end

end
