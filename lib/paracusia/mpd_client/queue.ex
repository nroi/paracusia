defmodule Paracusia.MpdClient.Queue do
  alias Paracusia.MpdClient
  alias Paracusia.MessageParser

  @moduledoc"""
  Functions related to the current playlist / queue.

  See also: https://musicpd.org/doc/protocol/queue.html

  Note that, unlike the official specification, we use the term "queue" rather than "playlist' in
  order to distinguish between MPD playlists saved in the playlists directory in m3u format, and the
  current playlist.
  Furthermore, we use the term `id` when referring to the unique identifier of a song in the entire
  database, and the term `position` when referring to a zero-based index inside the queue.
  """


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


  @doc"""
  Adds the file `uri` to the queue.
  Directories are added recursively. `uri` can also be a single file.
  """
  @spec add(String.t) :: :ok | MpdClient.mpd_error
  def add(uri) do
    MpdClient.send_and_ack('add "#{uri}"\n')
  end


  @doc"""
  Adds the `uri` at the given position to the queue (non-recursively) and returns the song id.
  """
  @spec add_id(String.t, position) :: {:ok, id} | MpdClient.mpd_error
  def add_id(uri, position) do
    msg = case position do
      nil -> 'addid "#{uri}"\n'
      pos -> 'addid "#{uri}" #{pos}\n'
    end
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      id = case reply do
        "Id: " <> rest ->
          {id, "\n"} = Integer.parse(rest)
          id
      end
      {:ok, id}
    end
  end


  @doc"""
  Adds the `uri` to the end of the queue (non-recursively) and returns the song id.
  """
  @spec add_id(String.t) :: {:ok, id} | MpdClient.mpd_error
  def add_id(uri) do
    msg = 'addid "#{uri}"\n'
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      id = case reply do
        "Id: " <> rest ->
          {id, "\n"} = Integer.parse(rest)
          id
      end
      {:ok, id}
    end
  end


  @doc"""
  Clears the queue.
  """
  @spec clear() :: :ok | MpdClient.mpd_error
  def clear() do
    MpdClient.send_and_ack("clear\n")
  end


  @doc"""
  Deletes the song at position or multiple songs from the given range from the queue.
  """
  @spec delete(position | range) :: :ok | MpdClient.mpd_error
  def delete({start, until}) do
    MpdClient.send_and_ack("delete #{start}:#{until}\n")
  end
  def delete(position) do
    MpdClient.send_and_ack("delete #{position}\n")
  end


  @doc"""
  Deletes the song with the given `id` from the queue.
  """
  @spec delete_id(id) :: :ok | MpdClient.mpd_error
  def delete_id(id) do
    MpdClient.send_and_ack("deleteid #{id}\n")
  end


  @doc"""
  Moves the song at `from` to `to` in the queue.

  `from` can be either a single position or a range.
  """
  @spec move(position | range, position) :: :ok | MpdClient.mpd_error
  def move({from, until}, to) do
    MpdClient.send_and_ack("move #{from}:#{until} #{to}\n")
  end
  def move(from, to) do
    MpdClient.send_and_ack("move #{from} #{to}\n")
  end


  @doc"""
  Moves the song with id `from` to position `to` in the queue.

  If `to` is negative, it is relative to the current song in the queue (if there is one).
  """
  def move_id(from, to) do
    MpdClient.send_and_ack("moveid #{from} #{to}\n")
  end


  @doc"""
  Returns all songs from the queue that match the given criteria.

  `needle` is the corresponding value that the given tag should have.
  """
  @spec find(tag, String.t) :: list | MpdClient.mpd_error
  def find(tag, needle) do
    msg = "playlistfind #{to_string(tag)} #{needle}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Returns a map containing info about the songs with the given id.
  """
  @spec song_info_from_id(id) :: map
  def song_info_from_id(id) do
    with {:ok, reply} <- MpdClient.send_and_recv("playlistid #{id}\n") do
      [item] = reply |> MessageParser.parse_items
      {:ok, item}
    end
  end


  @doc"""
  Returns a list of maps containing info about the songs currently in the queue.
  """
  @spec songs_info() :: [map]
  def songs_info() do
    with {:ok, reply} <- MpdClient.send_and_recv("playlistid\n") do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Returns a map containing info about the song at position `songpos`.
  """
  @spec song_info_from_pos(position) :: {:ok, map} | MpdClient.mpd_error
  def song_info_from_pos(songpos) do
    msg = "playlistinfo #{songpos}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      [item] = reply |> MessageParser.parse_items
      {:ok, item}
    end
  end


  @doc"""
  Returns a list of maps containing info about the songs in the given range.

  All returned songs are contained in the playlist in the range from `start` up to (excluding)
  `until`.
  """
  @spec songs_info_from_range(range) :: {:ok, [map]} | MpdClient.mpd_error
  def songs_info_from_range({start, until}) do
    msg = "playlistinfo #{start}:#{until}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Searches case-insensitively for partial matches in the queue.
  """
  @spec search(tag, String.t) :: {:ok, [map]} | MpdClient.mpd_error
  def search(tag, needle) do
    msg = "playlistsearch #{to_string(tag)} #{needle}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  defp parse_plchangesposid(msg) do
    split_at_cpos = msg
      |> String.trim_trailing("\n")
      |> String.split("\n", trim: true)
      |> Enum.reduce([], fn (item, acc) ->
        case item do
          "cpos: " <> _rest ->
            [[item] | acc]
          _ ->
            [x | xs ] = acc
            [[item | x] | xs]
        end
      end)
    split_at_cpos |> Enum.map(fn list ->
      list |> Enum.map(fn item ->
        case item |> String.split(": ", parts: 2) do
          [key,  value] -> {key, value}
        end
      end) |> Map.new
    end) |> Enum.reverse
  end


  # TODO once the API is complete, we need to update the sentence "To detect songs that were
  # detected…" and refer to the correct module/function.
  @doc"""
  Returns a list of maps containing all songs from the queue that changed since `version`.

  To detect songs that were deleted at the end of the playlist, use playlistlength returned by
  status command.
  """
  @spec changes(integer) :: {:ok, [map]} | MpdClient.mpd_error
  def changes(version) do
    msg = "plchanges #{version}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  # TODO once the API is complete, we need to update the sentence "To detect songs that were
  # detected…" and refer to the correct module/function.
  @doc"""
  Similar to `changes/1` but the songs contain only the position and the id instead of the complete
  metadata. This is more bandwith efficient.

  To detect songs that were deleted at the end of the playlist, use playlistlength returned by
  status command.
  """
  @spec changes_pos_id(integer) :: {:ok, [map]} | MpdClient.mpd_error
  def changes_pos_id(version) do
    msg = "plchangesposid #{version}\n"
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> parse_plchangesposid}
    end
  end


  @doc"""
  Sets the priority of the specified songs in the given range.

  A higher priority means that it will be played first when "random" mode is enabled. A priority is
  an integer between 0 and 255. The default priority of new songs is 0.
  """
  @spec set_priority(integer, range) :: :ok | MpdClient.mpd_error
  def set_priority(prio, {start, until}) do
    msg = "prio #{prio} #{start}:#{until}\n"
    MpdClient.send_and_ack(msg)
  end

  @doc"""
  Same as `set_priority/2`, except songs are addressed with their id.
  """
  @spec set_priority_from_id(integer, id | [id]) :: :ok | MpdClient.mpd_error
  def set_priority_from_id(prio, ids) when is_list(ids) do
    msg = 'prioid #{prio} #{ids |> Enum.join(" ")}\n'
    MpdClient.send_and_ack(msg)
  end
  def set_priority_from_id(prio, id) when is_integer(id) do
    msg = "prioid #{prio} #{id}\n"
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Specifies the portion of the song that shall be played.

  `start` and `until` are offsets in seconds (fractional seconds allowed). A song that is currently
  playing cannot be manipulated this way.
  """
  @spec range_id(id, integer, integer) :: :ok | MpdClient.mpd_error
  def range_id(id, start, until) do
    msg = "rangeid #{id} #{start}:#{until}\n"
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Removes the range that was previously set by calling `range_id/3`.
  """
  @spec remove_range(id) :: :ok | MpdClient.mpd_error
  def remove_range(id) do
    msg = "rangeid #{id} :\n"
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Shuffles the queue.
  """
  @spec shuffle() :: :ok | MpdClient.mpd_error
  def shuffle() do
    MpdClient.send_and_ack("shuffle\n")
  end


  @doc"""
  Shuffles the queue in the given range.
  """
  @spec shuffle(range) :: :ok | MpdClient.mpd_error
  def shuffle({start, until}) do
    MpdClient.send_and_ack("shuffle #{start}:#{until}\n")
  end


  @doc"""
  Swaps the positions of the songs at the given positions `pos1` and `pos2`.
  """
  @spec swap(position, position) :: :ok | MpdClient.mpd_error
  def swap(pos1, pos2) do
    MpdClient.send_and_ack("swap #{pos1}:#{pos2}\n")
  end


  @doc"""
  Swaps the positions of the songs with ids `id1` and `id2`.
  """
  @spec swapid(id, id) :: :ok | MpdClient.mpd_error
  def swapid(id1, id2) do
    MpdClient.send_and_ack("swapid #{id1}:#{id2}\n")
  end


  @doc"""
  Adds a tag to the song with the given id.

  Editing song tags is only possible for remote songs. This change is volatile: it may be
  overwritten by tags received from the server, and the data is gone when the song gets removed from
  the queue.
  """
  @spec add_tag_id(id, tag, String.t) :: :ok | MpdClient.mpd_error
  def add_tag_id(id, tag, value) do
    msg = "addtagid #{id} #{to_string(tag)} #{value}\n"
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Removes all tags from the song with the given id.
  """
  @spec clear_all_tags(id) :: :ok | MpdClient.mpd_error
  def clear_all_tags(id) do
    MpdClient.send_and_ack("cleartagid #{id}\n")
  end


  @doc"""
  Removes the given tag from the song with the given id.
  """
  @spec clear_tag_id(id, tag) :: :ok | MpdClient.mpd_error
  def clear_tag_id(id, tag) do
    MpdClient.send_and_ack("cleartagid #{id} #{to_string(tag)}\n")
  end

end
