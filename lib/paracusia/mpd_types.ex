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

  @typedoc"""
  positions are used to identify the position of a song in the queue. The first song in the queue
  has index 0.
  """
  @type position :: integer

  @typedoc"""
  ids are used by MPD to uniquely identify each song in the database. ids remain unchanged when a
  song changes its position in the queue.
  """
  @type id :: integer

  @typedoc"""
  Ranges are used to restrict an operation on a subset of the queue. A range is right-open and
  indexing starts with zero, e.g., {0, 3} is used to specify the songs at the 1st, 2nd and 3rd
  position.
  """
  @type range :: {position, position}

end
