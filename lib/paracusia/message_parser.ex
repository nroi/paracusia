defmodule Paracusia.MessageParser do
  @moduledoc false

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

  @doc"""
  Given a string like "directory: …\nfile: …,", return the corresponding list of tuples.
  """
  def parse_uris(m) do
    m |> String.split("\n", trim: true)
      |> Enum.map(fn item ->
        case item |> String.split(": ", parts: 2) do
          [first, second] -> {first, second}
        end
      end)
  end


  # Given a enumeration such as "Artist: Beatles\nArtist: Lady Gaga\n…", return the corresponding
  # list, e.g. ["Beatles", "Lady Gaga"].
  # TODO we used this function in at least one case only because we did not know that the result
  # could contain more data than just a simple key-value list. Check if we still need this function.
  def parse_newline_separated_enum(m) do
    m |> String.split("\n", trim: true)
      |> Enum.map(fn item -> case String.split(item, ": ", parts: 2) do
                               [_, value] -> value
                             end
                  end)
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

  def boolean_to_binary(false), do: 0
  def boolean_to_binary(true), do: 1
  def string_to_boolean("0"), do: false
  def string_to_boolean("1"), do: true

  defp outputs_from_map(%{"outputenabled" => enabled, "outputid" => id, "outputname" => name}) do
    %Paracusia.MpdClient.AudioOutputs{
      :outputenabled => string_to_boolean(enabled),
      :outputid => String.to_integer(id),
      :outputname => name
    }
  end


  @doc"""
  Given a list of tuples, create a the corresponding map with lists as values.

  ## Examples
      iex> Paracusia.MessageParser.to_list_map(foo: 1, foo: 2, foo: 3, bar: 23)
      %{foo: [1,2,3], bar: [23]}
  """
  def to_list_map(list) do
    reversed = Enum.reduce(list, %{}, fn ({key, value}, acc) ->
      {_, new_map} = Map.get_and_update(acc, key, fn current_value ->
        case current_value do
          nil    -> {current_value, [value]}
          values -> {current_value, [value | values]}
        end
      end)
      new_map
    end)
    Map.keys(reversed) |> Enum.reduce(%{}, fn (key, acc) ->
      Map.put(acc, key, Enum.reverse(reversed[key]))
    end)
  end


  @doc"""
  Splits the string into a list of lists using the attribute in the first line as delimiter.

  ## Examples

      iex> Paracusia.MessageParser.split_first_delim(
      ...> "plugin: mad\\nsuffix: mp3\\nsuffix: mp2\\nmime_type: audio/mpeg\\n" <>
      ...> "plugin: vorbis\\nsuffix: ogg\\n")
      [ ["plugin: mad", "suffix: mp3", "suffix: mp2", "mime_type: audio/mpeg"],
        ["plugin: vorbis", "suffix: ogg"]
      ]
  """
  def split_first_delim(s) do
    delim = case s |> String.split(": ", parts: 2) do
      [d, _] -> d
    end
    s
    |> String.split("\n", trim: true)
    |> Enum.reduce([], fn(line, acc) ->
         if String.starts_with?(line, delim) do
           [[line] | acc]
         else
           [x|xs] = acc
           [[line|x] | xs]
         end
       end)
    |> Enum.map(&Enum.reverse(&1))
    |> Enum.reverse
  end


  @doc"""
  Given a string composed newline-separated strings starting with "outputid: …", return the
  corresponding list of maps.
  """
  def parse_outputs(m) do
    string_map = split_first_delim(m) |> Enum.map(fn list ->
      list |> Enum.map(fn item ->
        case item |> String.split(": ", parts: 2) do
          [key,  value] -> {key, value}
        end
      end) |> Map.new
    end) |> Enum.reverse
    string_map |> Enum.map(&outputs_from_map(&1))
  end


  @doc"""
  Given a string such as "file: …\nartist: …\n…directory: …\nartist: …\n…", where a new entry
  starts with either "file" or "directory", return the corresponding list of maps.
  """
  def parse_items(m) do
    # Note that we just assume that each new item starts with "file: …" or "directory: …"
    # This seems to be the case, but it's not officially documented anywhere.
    split_at_id = m
      |> String.split("\n", trim: true)
      |> Enum.reduce([], fn (item, acc) ->
        case item do
          "playlist: " <> _rest ->
            [[item] | acc]
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
