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

  @spec songs(String.t) :: [map]
  def songs(m) do
    parse_items(m)
  end

  def current_song("") do
    nil
  end
  def current_song(m) do
    [item] = parse_items(m)
    item
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
      end) |> Map.new
    end) |> Enum.reverse
  end

end
