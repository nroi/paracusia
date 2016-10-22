defmodule Paracusia.MpdClient.Stickers do
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes
  alias Paracusia.MessageParser
  require Logger

  @moduledoc"""
  Functions related to Stickers.

  See also: https://musicpd.org/doc/protocol/stickers.html
  """


  @doc"""
  Returns the sticker value for the given URI.
  """
  @spec get(String.t, String.t) :: {:ok, String.t} | MpdTypes.mpd_error
  def get(uri, name) do
    # The type is always 'song' because that is currently (2016) the only supported type for
    # stickers.
    msg = ~s(sticker get song "#{uri}" "#{name}"\n)
    with {:ok, "sticker: " <> rest} <- MpdClient.send_and_recv(msg) do
      {:ok, rest |> String.replace_prefix("#{name}=", "") |> String.replace_suffix("\n", "")}
    end
  end


  @doc"""
  Sets the sticker `name` of `uri` to `value`.
  """
  @spec set(String.t, String.t, String.t) :: :ok | MpdTypes.mpd_error
  def set(uri, name, value) do
    msg = ~s(sticker set song "#{uri}" #{name} #{value}\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Deletes a sticker value from the song at the given URI.
  """
  @spec delete(String.t, String.t) :: :ok | MpdTypes.mpd_error
  def delete(uri, name) do
    msg = ~s(sticker delete song "#{uri}" "#{name}"\n)
    MpdClient.send_and_ack(msg)
  end


  @doc"""
  Deletes all sticker values from the song at the given URI.
  """
  @spec delete(String.t) :: :ok | MpdTypes.mpd_error
  def delete(uri) do
    msg = ~s(sticker delete song "#{uri}"\n)
    MpdClient.send_and_ack(msg)
  end


  # parse something like "sticker: key=value" into {key, value}
  defp parse_sticker("sticker: " <> rest) do
    case String.split(rest, "=", parts: 2) do
      [key, val] -> {key, val}
    end
  end


  @doc"""
  Returns all stickers for the song at the given URI.
  """
  @spec all(String.t) :: {:ok, map} | MpdTypes.mpd_error
  def all(uri) do
    msg = ~s(sticker list song "#{uri}"\n)
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      result = reply
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_sticker(&1))
      |> Map.new
      {:ok, result}
    end
  end


  @doc"""
  Searches inside `parent_uri` for songs with the given sticker `name` and returns a list of
  `{uri, value}` tuples where `value` is the sticker value of `uri` for `name`.
  """
  @spec find(String.t, String.t) :: {:ok, [{String.t, String.t}]} | MpdTypes.mpd_error
  def find(parent_uri, name) do
    msg = ~s(sticker find song "#{parent_uri}" "#{name}"\n)
    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      result = reply
      |> MessageParser.parse_items
      |>  Enum.map(fn map ->
        value = case String.split(map["sticker"], "=", parts: 2) do
          [_, val] -> val
        end
        {map["file"], value}
      end)
      {:ok, result}
    end
  end


  # "sticker find {TYPE} {URI} {NAME} = {VALUE}" is not implemented:
  # for some reason, MPD just responded with "OK\n" (i.e., no results) even though matches should
  # have occured.

end
