defmodule Paracusia.MpdClient.Playlists do
  alias Paracusia.MessageParser
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes

  @moduledoc"""
  Functions related to stored playlists.

  See also: https://musicpd.org/doc/protocol/playlist_files.html
  """


  @doc"""
  Returns a list containing all songs in the given playlist.
  """
  @spec list(String.t) :: {:ok, list} | MpdTypes.mpd_error
  def list(playlist) do
    msg = ~s(listplaylist "#{playlist}"\n)
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      result = reply
      |> String.split("\n", trim: true)
      |> Enum.map(fn "file: " <> rest -> rest end)
      {:ok, result}
    end
  end


  @doc"""
  Returns a map containing all songs from the playlist and their metadata.
  """
  @spec list_info(String.t) :: {:ok, [map]} | MpdTypes.mpd_error
  def list_info(playlist) do
    msg = ~s(listplaylistinfo "#{playlist}"\n)
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Returns a list of all playlists inside the playlists directory.
  """
  @spec list_all() :: {:ok, [map]} | MpdTypes.mpd_error
  def list_all() do
    with {:ok, reply} <- MpdClient.send_and_recv("listplaylists\n") do
      {:ok, reply |> MessageParser.parse_items}
    end
  end


  @doc"""
  Loads the playlist into the queue.
  """
  @spec load(String.t) :: :ok | MpdTypes.mpd_error
  def load(playlist) do
    MpdClient.send_and_ack(~s(load "#{playlist}"\n))
  end


  @doc"""
  Loads a given range from the playlist into the queue.

  Only songs whose position is between `start` and `until` (excluding `until`) are added to the
  queue. Indexing starts at zero.
  """
  @spec load(String.t, MpdTypes.range) :: :ok | MpdTypes.mpd_error
  def load(playlist, {start, until}) do
    MpdClient.send_and_ack(~s(load #{playlist} #{start}:#{until}\n))
  end


  @doc"""
  Adds `uri` to the playlist `playlist`.m3u

  `playlist`.m3u will be created if it does not already exist.
  """
  @spec add(String.t, String.t) :: :ok | MpdTypes.mpd_error
  def add(playlist, uri) do
    msg = ~s(playlistadd "#{playlist}" "#{uri}"\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Clears the playlist `playlist`.m3u
  """
  @spec clear(String.t) :: :ok | MpdTypes.mpd_error
  def clear(playlist) do
    msg = ~s(playlistclear "#{playlist}"\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Deletes the song at position `pos` from the playlist.

  Indexing starts at 0.
  """
  @spec delete(String.t, integer) :: :ok | MpdTypes.mpd_error
  def delete(playlist, pos) do
    msg = ~s(playlistdelete "#{playlist}" #{pos}\n)
    MpdClient.send_and_ack(msg)
  end

  @doc"""
  Moves the song at position `from` in the playlist `playlist`.m3u to the position `to`.
  """
  @spec move(String.t, integer, integer) :: :ok | MpdTypes.mpd_error
  def move(playlist, from, to) do
    msg = ~s(playlistmove "#{playlist}" #{from} #{to}\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Renames the playlist `playlist.m3u` to `new_name`.m3u
  """
  @spec rename(String.t, String.t) :: :ok | MpdTypes.mpd_error
  def rename(playlist, new_name) do
    msg = ~s(rename "#{playlist}" "#{new_name}"\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Removes the playlist `playlist`.m3u from the playlist directory.
  """
  @spec rm(String.t) :: :ok | MpdTypes.mpd_error
  def rm(playlist) do
    MpdClient.send_and_ack(~s(rm "#{playlist}"\n))
  end


  @doc"""
  Saves the current playlist to `name`.m3u in the playlist directory.
  """
  @spec save(String.t) :: :ok | MpdTypes.mpd_error
  def save(name) do
    MpdClient.send_and_ack(~s(save #{name}\n))
  end

end
