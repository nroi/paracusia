defmodule Paracusia.MpdClient.Status do
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes
  alias Paracusia.MessageParser
  alias Paracusia.PlayerState
  import Paracusia.MessageParser, only: [string_to_boolean: 1]

  @moduledoc """
  Functions related to the current status, e.g. volume, if playback is paused or stopped etc.

  See also: https://musicpd.org/doc/protocol/command_reference.html#status_commands
  Note that the MPD protocol specification also contains the "idle" and "clearerror" commands, which
  are not found in this module. This is because status updates (using the idle command) as well as
  error handling is done by Paracusia, hence the user need not use those commands explicitly.
  """

  @doc """
  Returns a map containing info about the current song.
  """
  @spec current_song() :: {:ok, map} | MpdTypes.mpd_error()
  def current_song() do
    with {:ok, reply} <- MpdClient.send_and_recv("currentsong\n") do
      {:ok, reply |> MessageParser.current_song()}
    end
  end

  defp nil_or_else(nil, _), do: nil
  defp nil_or_else(x, f), do: f.(x)

  @doc """
  Returns the current status of the player.
  """
  @spec status() :: {:ok, %PlayerState.Status{}} | MpdTypes.mpd_error()
  def status() do
    with {:ok, reply} <- MpdClient.send_and_recv("status\n") do
      status = reply |> MessageParser.parse_newline_separated()

      timestamp =
        case :os.timestamp() do
          {megasecs, secs, microsecs} ->
            megasecs * 1_000_000_000_000 + secs * 1_000_000 + microsecs
        end

      new_ps = %PlayerState.Status{
        :volume => String.to_integer(status["volume"]),
        :repeat => string_to_boolean(status["repeat"]),
        :random => string_to_boolean(status["random"]),
        :single => string_to_boolean(status["single"]),
        :consume => string_to_boolean(status["consume"]),
        :playlist => String.to_integer(status["playlist"]),
        :playlist_length => String.to_integer(status["playlistlength"]),
        :state =>
          case status["state"] do
            "play" -> :play
            "stop" -> :stop
            "pause" -> :pause
          end,
        :song_pos => status["song"] |> nil_or_else(&String.to_integer(&1)),
        :song_id => status["songid"] |> nil_or_else(&String.to_integer(&1)),
        :next_song_pos => status["nextsong"] |> nil_or_else(&String.to_integer(&1)),
        :next_song_id => status["nextsongid"] |> nil_or_else(&String.to_integer(&1)),
        :time => status["time"],
        :elapsed => status["elapsed"] |> nil_or_else(&String.to_float(&1)),
        :bitrate => status["bitrate"] |> nil_or_else(&String.to_integer(&1)),
        :xfade => status["xfade"] |> nil_or_else(&String.to_integer(&1)),
        :mixrampdb => status["mixrampdb"] |> nil_or_else(&String.to_float(&1)),
        :mixrampdelay => status["mixrampdelay"] |> nil_or_else(&String.to_integer(&1)),
        :audio =>
          status["audio"]
          |> nil_or_else(&Regex.run(~r/(.*):(.*):(.*)/, &1, capture: :all_but_first)),
        :updating_db => status["updating_db"] |> nil_or_else(&String.to_integer(&1)),
        :error => status["error"],
        :timestamp => timestamp
      }

      :ok = GenServer.cast(Paracusia.PlayerState, {:refresh_status, new_ps})
      {:ok, new_ps}
    end
  end

  @doc """
  Returns statistics.
  """
  @spec stats() :: {:ok, %Paracusia.PlayerState.Stats{}} | MpdTypes.mpd_error()
  def stats() do
    with {:ok, reply} <- MpdClient.send_and_recv("stats\n") do
      string_map = reply |> MessageParser.parse_newline_separated()

      {:ok,
       %PlayerState.Stats{
         artists: String.to_integer(string_map["artists"]),
         albums: String.to_integer(string_map["albums"]),
         songs: String.to_integer(string_map["songs"]),
         uptime: String.to_integer(string_map["uptime"]),
         db_playtime: String.to_integer(string_map["db_playtime"]),
         db_update: String.to_integer(string_map["db_update"]),
         playtime: String.to_integer(string_map["playtime"])
       }}
    end
  end
end
