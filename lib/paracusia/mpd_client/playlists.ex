defmodule Paracusia.MpdClient.Playlists do
  alias Paracusia.MessageParser
  alias Paracusia.MpdClient

  @moduledoc"""
  Functions related to stored playlists.

  See also: https://musicpd.org/doc/protocol/playlist_files.html
  """


  @doc"""
  Returns a list containing all songs in the given playlist.
  """
  @spec list(String.t) :: {:ok, list} | MpdClient.mpd_error
  def list(playlist) do
    msg = "listplaylist #{playlist}\n"
    with {:ok, reply} <- GenServer.call(MpdClient, {:send_and_recv, msg}) do
      result = reply
      |> String.split("\n", trim: true)
      |> Enum.map(fn "file: " <> rest -> rest end)
      {:ok, result}
    end
  end


  @doc"""
  Returns a map containing all songs from the playlist and their metadata.
  """
  @spec listinfo(String.t) :: {:ok, map} | MpdClient.mpd_error
  def listinfo(playlist) do
    msg = "listplaylistinfo #{playlist}\n"
    with {:ok, reply} <- GenServer.call(MpdClient, {:send_and_recv, msg}) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Returns a list of all playlists inside the playlists directory.
  """
  @spec list_all() :: {:ok, [map]} | MpdClient.mpd_error
  def list_all() do
    with {:ok, reply} <- GenServer.call(MpdClient, {:send_and_recv, "listplaylists\n"}) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Loads the playlist into the queue.
  """
  @spec load(String.t) :: :ok | MpdClient.mpd_error
  def load(playlist) do
    GenServer.call(MpdClient, {:send_and_ack, "load #{playlist}\n"})
  end


  @doc"""
  Loads a given range from the playlist into the queue.

  Only songs whose position is between `start` and `until` (excluding `until`) are added to the
  queue. Indexing starts at zero.
  """
  @spec load(String.t, integer, integer) :: :ok | MpdClient.mpd_error
  def load(playlist, start, until) do
    GenServer.call(MpdClient, {:send_and_ack, "load #{playlist} #{start}:#{until}\n"})
  end


  @doc"""
  Adds `uri` to the playlist `playlist`.m3u

  `playlist`.m3u will be created if it does not already exist.
  """
  @spec add(String.t, String.t) :: :ok | MpdClient.mpd_error
  def add(playlist, uri) do
    msg = "playlistadd #{playlist} #{uri}\n"
    GenServer.call(MpdClient, {:send_and_ack, msg})
  end


  @doc"""
  Clears the playlist `playlist`.m3u
  """
  @spec clear(String.t) :: :ok | MpdClient.mpd_error
  def clear(playlist) do
    msg = "playlistclear #{playlist}\n"
    GenServer.call(MpdClient, {:send_and_ack, msg})
  end


  @doc"""
  Deletes the song at position `pos` from the playlist.

  Indexing starts at 0.
  """
  @spec delete(String.t, integer) :: :ok | MpdClient.mpd_error
  def delete(playlist, pos) do
    msg = "playlistdelete #{playlist} #{pos}\n"
    GenServer.call(MpdClient, {:send_and_ack, msg})
  end

  @doc"""
  Moves the song at position `from` in the playlist `playlist`.m3u to the position `to`.
  """
  @spec move(String.t, integer, integer) :: :ok | MpdClient.mpd_error
  def move(playlist, from, to) do
    msg = "playlistmove #{playlist} #{from} #{to}\n"
    GenServer.call(MpdClient, {:send_and_ack, msg})
  end


  @doc"""
  Renames the playlist `playlist.m3u` to `new_name`.m3u
  """
  @spec rename(String.t, String.t) :: :ok | MpdClient.mpd_error
  def rename(playlist, new_name) do
    msg = "rename #{playlist} #{new_name}\n"
    GenServer.call(MpdClient, {:send_and_ack, msg})
  end


  @doc"""
  Removes the playlist `playlist`.m3u from the playlist directory.
  """
  @spec rm(String.t) :: :ok | MpdClient.mpd_error
  def rm(playlist) do
    GenServer.call(MpdClient, {:send_and_ack, "rm #{playlist}\n"})
  end


  @doc"""
  Saves the current playlist to `name`.m3u in the playlist directory.
  """
  @spec save(String.t) :: :ok | MpdClient.mpd_error
  def save(name) do
    GenServer.call(MpdClient, {:send_and_ack, "save #{name}\n"})
  end

end
