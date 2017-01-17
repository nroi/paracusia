defmodule Paracusia.DefaultEventHandler do
  alias Paracusia.PlayerState
  use GenServer
  require Logger

  @moduledoc"""
  Default event handler for all events received with MPD's "idle" command.

  For some events (player, playlist, mixer, outputs, options, message), the callback is called with
  the information required to do whatever needs to be done as a result of that event. For instance,
  when the next song is played, the "player" event is emitted and the corresponding clause is called
  with the `Paracusia.PlayerState`, which contains the new song as the value for the key
  `:current_song`. For other events, the callback is called only with the event itself, without any
  additional data structures describing the changed state.

  See https://musicpd.org/doc/protocol/command_reference.html#status_commands for more details.
  """

  def handle_info({:paracusia, :database_changed}, state = nil) do
    _ = Logger.info "database changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, :update_changed}, state = nil) do
    _ = Logger.info "database updated."
    {:noreply, state}
  end

  def handle_info({:paracusia, :stored_playlist_changed}, state = nil) do
    _ = Logger.info "stored playlists changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:playlist_changed, %PlayerState{}}}, state = nil) do
    _ = Logger.info "queue changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:player_changed, %PlayerState{}}}, state = nil) do
    _ = Logger.info "player changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:mixer_changed, %PlayerState{}}}, state = nil) do
    _ = Logger.info "mixer changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:outputs_changed, %PlayerState{}}}, state = nil) do
    _ = Logger.info "outputs changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:options_changed, %PlayerState{}}}, state = nil) do
    _ = Logger.info "options changed."
    {:noreply, state}
  end


  def handle_info({:paracusia, :sticker_changed}, state = nil) do
    _ = Logger.info "sticker changed."
    {:noreply, state}
  end

  def handle_info({:paracusia, {:subscription_changed, channels}}, state = nil) do
    # When the subscribe command is used, the subscribed-to channel will be created if it does not
    # already exist, That is why `channels` is among the arguments, it allows us to always maintain
    # an up-to-date list of all existing channels.
    _ = Logger.info "subscription changed. Currently available channels: #{inspect channels}"
    {:noreply, state}
  end

  def handle_info({:paracusia, {:message_changed, messages}}, state = nil) do
    _ = Logger.info "messages arrived: #{inspect messages}"
    {:noreply, state}
  end
end
