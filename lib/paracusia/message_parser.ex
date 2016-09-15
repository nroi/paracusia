defmodule Paracusia.MessageParser do
  alias Paracusia.Song

  def format_time(seconds) do
    justify = fn i ->
      i |> Integer.to_string |> String.rjust(2, ?0)
    end
    {secs_total, ""} = Integer.parse(seconds)
    hours = div(secs_total, 3600)
    mins = div(secs_total - hours * 3600, 60)
    secs = rem(secs_total, 60)
    if hours == 0 do
      "#{justify.(mins)}:#{justify.(secs)}"
    else
      "#{justify.(hours)}:#{justify.(mins)}:#{justify.(secs)}"
    end
  end

  defp proplist2song(proplist) do
    artist = case :proplists.get_value("Artist", proplist) do
      :undefined -> ""
      artist -> artist
    end
    track = case :proplists.get_value("Pos", proplist) do
      :undefined -> "unknown"
      track -> track
    end
    title = case :proplists.get_value("Title", proplist) do
      :undefined -> :proplists.get_value("file", proplist)
      title -> title
    end
    album = case :proplists.get_value("Album", proplist) do
      :undefined -> "unknown"
      album -> album
    end
    {duration, duration_in_secs} = case :proplists.get_value("Time", proplist) do
      :undefined -> nil
      seconds ->
        {total_seconds, ""} = Integer.parse(seconds)
        {format_time(seconds), total_seconds}
    end
    id = case :proplists.get_value("Id", proplist) do
      :undefined -> raise "Expected every song to have an ID"
      id -> id
    end
    %Song{
      artist: artist,
      track: track,
      title: title,
      album: album,
      duration: duration,
      id: id,
      duration_in_secs: duration_in_secs}
  end

  def songs(m) do
    proplists = parse_items(m)
    proplists |> Enum.map(&proplist2song(&1))
  end

  def current_song("") do
    nil
  end
  def current_song(m) do
    [proplist] = parse_items(m)
    proplist2song(proplist)
  end

  # Given a newline separated string (such as "volume: -1\nrepeat: 0\n), return the
  # corresponding map.
  def parse_newline_separated(m) do
    m |> String.split("\n", trim: true)
      |> Enum.map(
        fn item -> case String.split(item, ": ") do
          [key, value] -> {key, value}
        end end)
      |> Map.new
  end

  def parse_items(m) do
    # Note that we just assume that each new item starts with "file: …" or "directory: …"
    # This seems to be the case, but it's not officially documented anywhere.
    split_at_id = m
      |> String.trim_trailing("\n")
      |> String.split("\n", trim: true)
      |> Enum.reduce([], fn (item, acc) ->
      case item do
        "file: " <> _rest ->
          [[item] | acc]
        "directory: " <> _rest ->
          [[item] | acc]
        _ ->
          [x | xs ] = acc
          [[item | x] | xs]
      end
    end)
    split_at_id |> Enum.map(fn list ->
      list |> Enum.map(fn item ->
        case item |> String.split(": ", parts: 2) do
          [key,  value] -> {key, value}
        end
      end) |> Enum.reverse
    end) |> Enum.reverse
  end

end
