defmodule Paracusia.MpdClient.Playback do
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes
  alias Paracusia.PlayerState
  import Paracusia.MessageParser, only: [boolean_to_binary: 1]

  @moduledoc """
  Functions related to MPD's playback.

  See also: https://musicpd.org/doc/protocol/playback_commands.html and
  https://musicpd.org/doc/protocol/playback_option_commands.html
  """

  @doc """
  Continues playing the current song.
  """
  @spec play() :: :ok | MpdTypes.mpd_error()
  def play() do
    MpdClient.send_and_ack("play\n")
  end

  @doc """
  Pauses or resumes playback.
  """
  @spec pause(boolean) :: :ok | MpdTypes.mpd_error()
  def pause(true), do: MpdClient.send_and_ack("pause 1\n")
  def pause(false), do: MpdClient.send_and_ack("pause 0\n")

  @doc """
  Plays next song in the queue.
  """
  @spec next() :: :ok | MpdTypes.mpd_error()
  def next do
    MpdClient.send_and_ack("next\n")
  end

  @doc """
  Plays previous song in the queue.
  """
  @spec previous() :: :ok | MpdTypes.mpd_error()
  def previous do
    MpdClient.send_and_ack("previous\n")
  end

  @doc """
  Begins playing the queue at the given position.
  """
  @spec play_pos(MpdTypes.position()) :: :ok | MpdTypes.mpd_error()
  def play_pos(position) do
    MpdClient.send_and_ack("play #{position}\n")
  end

  @doc """
  Begins playing the queue at song `songid`.
  """
  @spec play_id(MpdTypes.id()) :: :ok | MpdTypes.mpd_error()
  def play_id(songid) do
    MpdClient.send_and_ack("playid #{songid}\n")
  end

  @doc """
  Seeks to the position `seconds` at entry `songpos` in the queue.
  """
  @spec seek_pos(MpdTypes.position(), number) :: :ok | MpdTypes.mpd_error()
  def seek_pos(songpos, seconds) do
    MpdClient.send_and_ack("seek #{songpos} #{seconds}\n")
  end

  @doc """
  Seeks to the position `seconds` of song `id`.
  """
  @spec seek_id(MpdTypes.id(), number) :: :ok | MpdTypes.mpd_error()
  def seek_id(id, seconds) do
    MpdClient.send_and_ack("seekid #{id} #{seconds}\n")
  end

  @doc """
  Seeks to the position `seconds` within the current song.
  """
  @spec seek_current(number) :: :ok | MpdTypes.mpd_error()
  def seek_current(seconds) do
    MpdClient.send_and_ack("seekcur #{seconds}\n")
  end

  @doc """
  Seeks `seconds` seconds forward within the current song.
  """
  @spec seek_current_forward(number) :: :ok | MpdTypes.mpd_error()
  def seek_current_forward(seconds) do
    MpdClient.send_and_ack("seekcur +#{seconds}\n")
  end

  @doc """
  Seeks `seconds` seconds backward within the current song.
  """
  @spec seek_current_backward(number) :: :ok | MpdTypes.mpd_error()
  def seek_current_backward(seconds) do
    MpdClient.send_and_ack("seekcur -#{seconds}\n")
  end

  @doc """
  Stops playing.
  """
  @spec stop() :: :ok | MpdTypes.mpd_error()
  def stop do
    MpdClient.send_and_ack("stop\n")
  end

  @doc """
  Sets consume state to true or false.
  """
  @spec consume(boolean) :: :ok | MpdTypes.mpd_error()
  def consume(state) do
    MpdClient.send_and_ack("consume #{boolean_to_binary(state)}\n")
  end

  @doc """
  Sets crossfading between songs.
  """
  @spec crossfade(integer) :: :ok | MpdTypes.mpd_error()
  def crossfade(seconds) do
    MpdClient.send_and_ack("crossfade #{seconds}\n")
  end

  @doc """
  Sets the threshold at which songs will be overlapped.

  Like crossfading but doesn't fade the track volume, just overlaps. The songs need to have MixRamp
  tags added by an external tool. 0dB is the normalized maximum volume so use negative values. In
  the absence of mixramp tags, crossfading will be used.
  """
  @spec mixrampdb(integer) :: :ok | MpdTypes.mpd_error()
  def mixrampdb(decibels) do
    MpdClient.send_and_ack("mixrampdb #{decibels}\n")
  end

  @doc """
  Sets random state to true or false.
  """
  @spec random(boolean) :: :ok | MpdTypes.mpd_error()
  def random(state) do
    MpdClient.send_and_ack("random #{boolean_to_binary(state)}\n")
  end

  @doc """
  Sets repeat state to true or false.
  """
  @spec repeat(boolean) :: :ok | MpdTypes.mpd_error()
  def repeat(state) do
    MpdClient.send_and_ack("repeat #{boolean_to_binary(state)}\n")
  end

  @doc """
  Sets volume to `vol` (value between 0 and 100).
  """
  @spec set_volume(integer) :: :ok | MpdTypes.mpd_error()
  def set_volume(vol) do
    MpdClient.send_and_ack("setvol #{vol}\n")
  end

  @doc """
  Sets single state to true or false.
  """
  @spec single(boolean) :: :ok | MpdTypes.mpd_error()
  def single(state) do
    MpdClient.send_and_ack("single #{boolean_to_binary(state)}\n")
  end

  @doc """
  Sets the replay gain mode.

  Changing the mode during playback may take several seconds, because the new setting does not
  affect the buffered data.
  """
  @spec replay_gain_mode(:off | :track | :album | :auto) :: :ok | MpdTypes.mpd_error()
  def replay_gain_mode(:off), do: MpdClient.send_and_ack("replay_gain_mode off\n")
  def replay_gain_mode(:track), do: MpdClient.send_and_ack("replay_gain_mode track\n")
  def replay_gain_mode(:album), do: MpdClient.send_and_ack("replay_gain_mode album\n")
  def replay_gain_mode(:auto), do: MpdClient.send_and_ack("replay_gain_mode auto\n")

  @doc """
  Prints replay gain options. Currently, only the variable replay_gain_mode is returned.
  """
  @spec replay_gain_status() :: {:ok, String.t()} | MpdTypes.mpd_error()
  def replay_gain_status, do: MpdClient.send_and_recv("replay_gain_status\n")

  @doc """
  Changes volume by amount `change`.

  Note: the MPD command used by this function is deprecated, use `set_volume/1` instead.
  """
  @spec volume(integer) :: :ok | MpdTypes.mpd_error()
  def volume(change), do: MpdClient.send_and_ack("volume #{change}\n")

  @doc """
  Seeks the current song to `percent` percent.
  """
  @spec seek_percent(number) :: :ok | MpdTypes.mpd_error()
  def seek_percent(percent) do
    duration = PlayerState.current_song()["Time"] |> String.to_integer()
    secs = duration * (percent / 100)
    seek_current(secs)
  end
end
