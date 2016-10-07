defmodule Paracusia.MpdTypes do

  @typedoc"""
  See https://musicpd.org/doc/protocol/response_syntax.html#failure_response_syntax for more
  details.
  """
  @type mpd_error :: {:error, {String.t, String.t}}


  @typedoc"""
  As described at https://musicpd.org/doc/protocol/tags.html
  """
  @type tag :: :artist |
               :artistsort |
               :album |
               :albumsort |
               :albumartist |
               :albumartistsort |
               :title |
               :track |
               :name |
               :genre |
               :date |
               :composer |
               :performer |
               :comment |
               :disc |
               :musicbrainz_artistid |
               :musicbrainz_albumid |
               :musicbrainz_albumartistid |
               :musicbrainz_trackid |
               :musicbrainz_releasetrackid

end
