defmodule Paracusia.DefaultEventHandler do
  alias Paracusia.PlayerState
  use GenEvent
  require Logger

  @moduledoc"""
  Default event handler for all events received with MPD's "idle" command.

  For some events (player, playlist, mixer, outputs, options, message), the callback is called with
  the information required to do whatever needs to be done as a result of that event. For instance,
  when the next song is played, the "player" event is emitted and the corresponding clause is called
  with the `%PlayerState`, which contains the new song as the value for the key `:current_song`. For
  other events, the callback is called only with the event itself, without any additional data
  structures describing the changed state.

  See https://musicpd.org/doc/protocol/command_reference.html#status_commands for more details.
  """

  def handle_event(:database_changed, state = nil) do
    _ = Logger.info "database changed."
    {:ok, state}
  end

  def handle_event(:update_changed, state = nil) do
    _ = Logger.info "database updated."
    {:ok, state}
  end

  def handle_event(:stored_playlist_changed, state = nil) do
    _ = Logger.info "stored playlists changed."
    {:ok, state}
  end

  def handle_event({:playlist_changed, %PlayerState{}}, state = nil) do
    _ = Logger.info "queue changed."
    {:ok, state}
  end

  def handle_event({:player_changed, %PlayerState{}}, state = nil) do
    _ = Logger.info "player changed."
    {:ok, state}
  end

  def handle_event({:mixer_changed, %PlayerState{}}, state = nil) do
    _ = Logger.info "mixer changed."
    {:ok, state}
  end

  def handle_event({:outputs_changed, %PlayerState{}}, state = nil) do
    _ = Logger.info "outputs changed."
    {:ok, state}
  end

  def handle_event({:options_changed, %PlayerState{}}, state = nil) do
    _ = Logger.info "options changed."
    {:ok, state}
  end


  def handle_event(:sticker_changed, state = nil) do
    _ = Logger.info "sticker changed."
    {:ok, state}
  end

  def handle_event({:subscription_changed, channels}, state = nil) do
    # When the subscribe command is used, the subscribed-to channel will be created if it does not
    # already exist, That is why `channels` is among the arguments, it allows us to always maintain
    # an up-to-date list of all existing channels.
    _ = Logger.info "subscription changed. Currently available channels: #{inspect channels}"
    {:ok, state}
  end

  def handle_event({:message_changed, messages}, state = nil) do
    _ = Logger.info "messages arrived: #{inspect messages}"
    {:ok, state}
  end
end
