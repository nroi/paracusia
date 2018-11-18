defmodule Paracusia.MpdClient.Database do
  alias Paracusia.MpdClient
  alias Paracusia.MpdClient.Database.FindExpression
  alias Paracusia.MpdTypes
  alias Paracusia.MessageParser
  require Logger

  @moduledoc """
  Functions related to the music database.

  See also: https://musicpd.org/doc/protocol/database.html
  """

  # Parses a string such as:
  #   Album: Baby Darling Doll Face Honey
  #   songs: 12
  #   playtime: 2876
  #   Album: By Default
  #   songs: 12
  #   playtime: 2435
  # i.e., multiple results denoted by the first property ("Album", in this case).
  @spec parse_query_result(String.t()) :: [map]
  defp parse_query_result(m) do
    [delimiter, _] = m |> String.split(": ", parts: 2)

    m
    |> String.split("\n", trim: true)
    |> Enum.reduce([], fn item, acc ->
      if item |> String.starts_with?(delimiter) do
        [[item] | acc]
      else
        [x | xs] = acc
        [[item | x] | xs]
      end
    end)
    |> Enum.map(fn list ->
      list
      |> Enum.map(fn item ->
        case item |> String.split(": ", parts: 2) do
          ["playtime", value] -> {"playtime", String.to_integer(value)}
          ["songs", value] -> {"songs", String.to_integer(value)}
          [key, value] -> {key, value}
        end
      end)
      |> Map.new()
    end)
    |> Enum.reverse()
  end

  defp find_expression_to_string(fe = %FindExpression{}) do
    filter_string =
      fe.filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{MessageParser.find_tag_to_string(tag)} "#{value}" )
      end)

    filter_msg = "#{filter_string}"

    sort_msg = case fe.order_by do
      nil -> ""
      tag ->
        prefix = case fe.sort_direction do
          :asc -> ""
          :desc -> "-"
        end
        " sort #{prefix}#{tag}"
    end

    window_msg = case fe.window do
      nil -> ""
      {from, until} ->
        " window #{from}:#{until}"
    end

    filter_msg <> sort_msg <> window_msg
  end

  @doc """
  Returns the total playtime and number of songs that match the given filters.

  ## Example

      Paracusia.MpdClient.Database.count(albumartist: "Rammstein", album: "Mutter")
      {:ok, %{"playtime" => 3048, "songs" => 11}}
  """
  @spec count([{MpdTypes.tag(), String.t()}]) :: {:ok, map} | MpdTypes.mpd_error()
  def count(filters) do
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{to_string(tag)} "#{value}" )
      end)

    msg = "count #{filter_string}\n"

    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      [result] = reply |> parse_query_result
      {:ok, result}
    end
  end

  @doc """
  Same as `count/1`, but results are grouped with the additional parameter `group`.

  ## Example

      # Show the number of songs and total playlength of each album by "Rammstein":
      Paracusia.MpdClient.Database.count_grouped(:album, albumartist: "Rammstein")
      {:ok,
        [%{"Album" => "Mutter", "playtime" => 3048, "songs" => 11},
         %{"Album" => "Reise, Reise", "playtime" => 3385, "songs" => 14}]}
  """
  @spec count_grouped(MpdTypes.tag(), [{MpdTypes.tag(), String.t()}]) ::
          {:ok, [map]} | MpdTypes.mpd_error()
  def count_grouped(group, filters \\ []) do
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{to_string(tag)} "#{value}" )
      end)

    msg = "count #{filter_string}group #{to_string(group)}\n"

    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> parse_query_result}
    end
  end

  @doc """
  Returns all songs that match the given filters.

  ## Example

      # Return all songs by "Rammstein" in the album "Mutter":
      Paracusia.MpdClient.Database.find(albumartist: "Rammstein", album: "Mutter")
      {:ok,
        [%{"Album" => "Mutter", "AlbumArtist" => "Rammstein",
            "Date" => "2001", "Time" => "280", "Title" => "Mein Herz brennt",
            "file" => "flac/rammstein_-_mutter/rammstein_mein_herz_brennt.flac", …},
          %{"Album" => "Mutter", "AlbumArtist" => "Rammstein",
            "Date" => "2001", "Time" => "217", "Title" => "Links 2-3-4",
            "file" => "flac/rammstein_-_mutter_(2001)/02._rammstein_links_2_3_4.flac", …},
          …
          ]
      }
  """
  @spec find([{MpdTypes.find_tag(), String.t()}]) :: {:ok, [map]} | MpdTypes.mpd_error()
  def find(filters) when is_list(filters) do
    get(%FindExpression{filters: filters})
  end

  @spec filter([{MpdTypes.find_tag(), String.t()}]) :: FindExpression.t
  def filter(filters) when is_list(filters) do
    %FindExpression{filters: filters}
  end

  @doc """
  Returns the given `FindExpression` with the `order_by` restriction added.
  See `get/1` for an example.
  """
  @spec order_by(FindExpression.t, MpdTypes.tag()) :: FindExpression.t
  def order_by(fe = %FindExpression{}, tag) do
    %{fe | :order_by => tag, :sort_direction => :asc}
  end

  @doc """
  Returns the given `FindExpression` with the `order_by` restriction added. Results
  will be sorted by `tag` in ascending order.
  See `get/1` for an example.
  """
  @spec order_by(FindExpression.t, MpdTypes.tag(), MpdTypes.sort_direction()) :: FindExpression.t
  def order_by(fe = %FindExpression{}, tag, sort_direction = :asc) do
    %{fe | :order_by => tag, :sort_direction => sort_direction}
  end

  def order_by(fe = %FindExpression{}, tag, sort_direction = :desc) do
    %{fe | :order_by => tag, :sort_direction => sort_direction}
  end

  def window(fe = %FindExpression{}, from, until) do
    %{fe | :window => {from, until}}
  end

  @doc """
  Returns all songs that match the given filter expression.

  ## Example

      # Return the first three songs by "Koan" in the album "Proteus", in descending order sorted by
      # their title:
        Paracusia.MpdClient.Database.filter(albumartist: "Koan", album: "Proteus")
        |> Paracusia.MpdClient.Database.order_by("Title", :desc)
        |> Paracusia.MpdClient.Database.window(0, 3)
        |> Paracusia.MpdClient.Database.get
        {:ok,
          [
            %{
              "Album" => "Proteus",
              "AlbumArtist" => "Koan",
              "AlbumArtistSort" => "Koan",
              "Title" => "Splice (White mix)",
              …
            },
            %{
              "Album" => "Proteus",
              "AlbumArtist" => "Koan",
              "AlbumArtistSort" => "Koan",
              "Artist" => "Koan",
              "Title" => "Eidotheia (radio version)",
              …
            },
            %{
              "Album" => "Proteus",
              "AlbumArtist" => "Koan",
              "AlbumArtistSort" => "Koan",
              "Title" => "Arachne (Fatum Sci-Fi version)",
              }
          ]
        }
  """
  def get(fe = %FindExpression{}) do
    msg = "find #{find_expression_to_string(fe)}\n"

    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items()}
    end
  end

  @doc """
  Adds all songs that match the given filters to the queue.

  ## Example

      # Add album "Mutter" by "Rammstein":
      Paracusia.MpdClient.Database.find_add(albumartist: "Rammstein", album: "Mutter")
      :ok
  """
  @spec find_add([{MpdTypes.find_tag(), String.t()}]) :: :ok | MpdTypes.mpd_error()
  def find_add(filters) when is_list(filters) do
    fe = %FindExpression{filters: filters}
    msg = "findadd #{find_expression_to_string(fe)}\n"

    MpdClient.send_and_ack(msg)
  end


  @doc """
  Returns unique tag values that match the given query.

  `tag` specifies which tag values should be returned.
  `filter` allows to specify a list of tag-value pairs to filter the results.

  ## Example

      # Return all albums released by Rammstein in 2001:
      Paracusia.MpdClient.Database.list(:album, albumartist: "Rammstein", date: 2001)
      {:ok, ["Mutter"]}
  """
  @spec list(MpdTypes.tag() | :file, [{MpdTypes.tag(), String.t()}]) ::
          {:ok, [map]} | MpdTypes.mpd_error()
  def list(tag, filters \\ []) do
    # The 'group' keyword for the 'list' command is currently unsupported.
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{to_string(tag)} "#{value}" )
      end)

    msg = "list #{to_string(tag)} #{filter_string}\n"

    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_newline_separated_enum()}
    end
  end

  @doc """
  Lists all songs and directories in `uri`.

  Usage of this command is discouraged by the author of MPD.
  """
  @spec list_all(String.t()) :: {:ok, [{String.t(), String.t()}]} | MpdTypes.mpd_error()
  def list_all(uri) do
    with {:ok, reply} <- MpdClient.send_and_recv(~s(listall "#{uri}"\n)) do
      {:ok, reply |> MessageParser.parse_uris()}
    end
  end

  @doc """
  Same as `list_all/1`, except it also returns metadata info.

  Usage of this command is discouraged by the author of MPD.
  """
  @spec list_all_info(String.t()) :: {:ok, [map]} | MpdTypes.mpd_error()
  def list_all_info(uri \\ "") do
    with {:ok, reply} <- MpdClient.send_and_recv(~s(listallinfo "#{uri}"\n)) do
      {:ok, reply |> MessageParser.parse_items()}
    end
  end

  @doc """
  Returns the contents of the directory `uri`, including files are not recognized by MPD.

  `uri` can be a path relative to the music directory or an URI understood by one of the storage
  plugins.
  """
  @spec list_files(String.t()) :: {:ok, [map]} | MpdTypes.mpd_error()
  def list_files(uri \\ "") do
    with {:ok, reply} <- MpdClient.send_and_recv(~s(listfiles "#{uri}"\n)) do
      {:ok, reply |> MessageParser.parse_items()}
    end
  end

  @doc """
  Returns the contents of the directory `uri`.

  When listing the root directory, this currently returns the list of stored playlists. This
  behavior is deprecated; use `Paracusia.MpdClient.Playlists.list_all/0` instead.
  This command may be used to list metadata of remote files (e.g. `uri` beginning with "http://" or
  "smb://").
  Clients that are connected via UNIX domain socket may use this command to read the tags of an
  arbitrary local file (the URI is an absolute path).
  """
  @spec lsinfo(String.t()) :: {:ok, [map]} | MpdTypes.mpd_error()
  def lsinfo(uri \\ "") do
    with {:ok, reply} <- MpdClient.send_and_recv(~s(lsinfo "#{uri}"\n)) do
      {:ok, reply |> MessageParser.parse_items()}
    end
  end

  @doc """
  Returns "comments" (i.e., key-value pairs) from the file specified by `uri`.

  `uri` can be a path relative to the music directory or an absolute path.
  May also be used to list metadata of remote files (e.g. URI beginning with "http://" or
  "smb://").
  The meaning of the returned key-value pairs depends on the codec, and not all decoder plugins support it.
  """
  @spec read_comments(String.t()) :: {:ok, map} | MpdTypes.mpd_error()
  def read_comments(uri) do
    with {:ok, reply} <- MpdClient.send_and_recv(~s(readcomments "#{uri}"\n)) do
      lines =
        case reply |> String.split("\n", trim: true) do
          # map over empty sequence if server has replied with newline
          [""] ->
            []

          x ->
            x
        end

      result =
        lines
        |> Enum.reduce(%{}, fn line, acc ->
          case String.split(line, ": ", parts: 2) do
            [key, val] -> Map.put(acc, key, val)
          end
        end)

      {:ok, result}
    end
  end

  @doc """
  Case-insensitive version of `find/1`.
  """
  @spec search([{MpdTypes.find_tag(), String.t()}]) :: {:ok, [map]} | MpdTypes.mpd_error()
  def search(filters) do
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{to_string(tag)} "#{value}" )
      end)

    msg = "search #{filter_string}\n"

    with {:ok, reply} <- MpdClient.send_and_recv(msg) do
      {:ok, reply |> MessageParser.parse_items()}
    end
  end

  @doc """
  Case-insensitive version of `find_add/1`.
  """
  @spec search_add([{MpdTypes.find_tag(), String.t()}]) :: :ok | MpdTypes.mpd_error()
  def search_add(filters) do
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{MessageParser.find_tag_to_string(tag)} "#{value}" )
      end)

    MpdClient.send_and_ack("searchadd #{filter_string}\n")
  end

  @doc """
  Performs a case-insensitive search with the given filters and adds matching songs to the given
  playlist.

  ## Example

      Paracusia.MpdClient.Database.search_add_playlist("Mutter by Rammstein", albumartist: "Rammstein", album: "Mutter")
      :ok
  """
  @spec search_add_playlist(String.t(), [{MpdTypes.find_tag(), String.t()}]) ::
          :ok | MpdTypes.mpd_error()
  def search_add_playlist(playlist, filters) do
    filter_string =
      filters
      |> Enum.reduce("", fn {tag, value}, acc ->
        acc <> ~s(#{MessageParser.find_tag_to_string(tag)} "#{value}" )
      end)

    MpdClient.send_and_ack(~s(searchaddpl "#{playlist}" #{filter_string}\n))
  end

  @doc """
  Updates the entire music database and returns the job id.

  Find new files, remove deleted files and update modified files. The returned id is used to
  identify the update job. The current job id can be read from
  `Paracusia.MpdClient.Status.status/0` (updating_db).
  """
  @spec update() :: {:ok, pos_integer()} | MpdTypes.mpd_error()
  def update() do
    with {:ok, "updating_db: " <> rest} <- MpdClient.send_and_recv("update\n") do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer()
      {:ok, job_id}
    end
  end

  @doc """
  Same as `update/0`, but only the given URI (directory or file) is updated.
  """
  @spec update(String.t()) :: {:ok, pos_integer()} | MpdTypes.mpd_error()
  def update(uri) do
    with {:ok, "updating_db: " <> rest} <- MpdClient.send_and_recv(~s(update "#{uri}"\n)) do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer()
      {:ok, job_id}
    end
  end

  @doc """
  Same as `update/0`, but also rescans unmodified files.
  """
  @spec rescan() :: {:ok, pos_integer()} | MpdTypes.mpd_error()
  def rescan() do
    with {:ok, "updating_db: " <> rest} <- MpdClient.send_and_recv("rescan\n") do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer()
      {:ok, job_id}
    end
  end

  @doc """
  Same as `update/1`, but also rescans unmodified files.
  """
  @spec rescan(String.t()) :: {:ok, pos_integer()} | MpdTypes.mpd_error()
  def rescan(uri) do
    with {:ok, "updating_db: " <> rest} <- MpdClient.send_and_recv(~s(rescan "#{uri}"\n)) do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer()
      {:ok, job_id}
    end
  end
end
