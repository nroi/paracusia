defmodule Paracusia.MpdClient.PlaybackTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Playback

  setup_all do
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "commands that do not return a message should return :ok" do
    :ok = Playback.next
    :ok = Playback.pause(false)
    :ok = Playback.pause(true)
    :ok = Playback.stop()
    :ok = Playback.play()
    :ok = Playback.play_pos(1)
    :ok = Playback.play_id(1)
    :ok = Playback.play_id()
    :ok = Playback.previous()
    :ok = Playback.seek_pos(0, 30)
    :ok = Playback.seek_id(0, 30)
    :ok = Playback.seek_current(30)
    :ok = Playback.seek_current_forward(30)
    :ok = Playback.seek_current_backward(30)
    :ok = Playback.consume(true)
    :ok = Playback.consume(false)
    :ok = Playback.crossfade(1)
    :ok = Playback.mixrampdb(1)
    :ok = Playback.random(true)
    :ok = Playback.random(false)
    :ok = Playback.repeat(true)
    :ok = Playback.repeat(false)
    :ok = Playback.set_volume(0)
    :ok = Playback.single(true)
    :ok = Playback.single(false)
    :ok = Playback.replay_gain_mode(:off)
    :ok = Playback.replay_gain_mode(:track)
    :ok = Playback.replay_gain_mode(:album)
    :ok = Playback.replay_gain_mode(:auto)
    :ok = Playback.volume(1)
    :ok = Playback.seek_percent(50.0)
  end

  test "replay_gain_status should return the current status" do
    {:ok, "replay_gain_mode: " <> _} = Playback.replay_gain_status
  end


end
