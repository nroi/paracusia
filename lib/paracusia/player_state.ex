defmodule Paracusia.PlayerState do
  alias Paracusia.MpdClient
  alias Paracusia.PlayerState
  require Logger
  use GenServer

  @type t :: %PlayerState{current_song: nil | map,
                          playlist: list,
                          status: %Paracusia.PlayerState.Status{},
                          outputs: list}
  defstruct current_song: nil,
  # TODO stay consistent with the existing terminology: Use 'queue' for the current playlist.
            playlist: [],
            status: %Paracusia.PlayerState.Status{},
            outputs: []


  @moduledoc"""
  Provides access to the current state of MPD, without having to send messages over the socket.

  All functions in this module have a pendant in a submodule of `Paracusia.MpdClient` (but not vice
  versa). Using these functions instead of the ones in `Paracusia.MpdClient` has the advantage that
  that latency is lower and no superfluous TCP messages are sent.
  """


  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end


  @doc"""
  Similar to `Paracusia.MpdClient.status.current_song/0`, but returns `nil` if no song is available.
  """
  @spec current_song() :: %{String.t => String.t} | nil
  def current_song() do
    GenServer.call(__MODULE__, :current_song)
  end


  @doc"""
  Similar to `Paracusia.MpdClient.AudioOutputs.all/0`, but always returns the outputs (instead of
  :error).
  """
  def audio_outputs do
    GenServer.call(__MODULE__, :audio_outputs)
  end


  @doc"""
  Similar to `Paracusia.MpdClient.Queue.songs_info/0`, but always returns the queue (instead of
  :error).
  """
  @spec queue() :: %{String.t => String.t}
  def queue do
    GenServer.call(__MODULE__, :queue)
  end


  @doc"""
  Similar to `Paracusia.MpdClient.Status.status/0`, but always returns the status (instead of
  :error).

  Note that calling `Paracusia.MpdClient.Status.status/0` will insert the current timestamp into the
  result while this function will return the timestamp when the status was last updated.
  """
  @spec status() :: %Paracusia.PlayerState.Status{}
  def status do
    GenServer.call(__MODULE__, :status)
  end


  def init(nil) do
    {:ok, current_song} = MpdClient.Status.current_song
    {:ok, playlist} = MpdClient.Queue.songs_info
    {:ok, status} = MpdClient.Status.status
    {:ok, outputs} = MpdClient.AudioOutputs.all
    player_state = %PlayerState{current_song: current_song,
                                playlist: playlist,
                                status: status,
                                outputs: outputs}
    {:ok, genevent_pid} = GenEvent.start_link()
    case Application.get_env(:paracusia, :event_handler) do
      nil ->
        :ok = GenEvent.add_handler(genevent_pid, Paracusia.DefaultEventHandler, nil)
      event_handler ->
        :ok = GenEvent.add_handler(genevent_pid, event_handler, nil)
    end
    _ = Logger.debug "[playerstate] initial player state is: #{inspect player_state}"
    {:ok, {player_state, genevent_pid}}
  end

  defp new_ps_from_events(ps, events) do
    new_outputs = if Enum.member?(events, :outputs_changed) do
      {:ok, outputs} = MpdClient.AudioOutputs.all
      outputs
    else
      ps.outputs
    end
    current_song_obsolete = Enum.any?(events, fn event ->
      case event do
        :player_changed -> true
        :playlist_changed -> true # in case the previously playing song was deleted from queue
        _ -> false
      end
    end)
    new_current_song = if current_song_obsolete do
      {:ok, current_song} = MpdClient.Status.current_song
      current_song
    else
      ps.current_song
    end
    new_playlist = if Enum.member?(events, :playlist_changed) do
      {:ok, playlist} = MpdClient.Queue.songs_info
      playlist
    else
      ps.playlist
    end
    status_changed = Enum.any?([:mixer_changed, :player_changed, :options_changed], fn subsystem ->
      Enum.member?(events, subsystem)
    end)
    new_status = if status_changed do
      {:ok, status} = MpdClient.Status.status
      status
    else
      ps.status
    end
    %PlayerState{
      :current_song => new_current_song,
      :playlist => new_playlist,
      :status => new_status,
      :outputs => new_outputs,
    }
  end


  # called by MpdClient process when MPD has sent new changes.
  def handle_cast({:events, []}, state), do: {:noreply, state}
  def handle_cast({:events, events}, {ps = %PlayerState{}, handler}) do
    _ = Logger.debug "Received the following idle events: #{inspect events}"
    new_ps = new_ps_from_events(ps, events)
    Enum.each(events, fn e ->
      case e do
        :update_changed ->
          GenEvent.notify(handler, e)
        :stored_playlist_changed ->
          GenEvent.notify(handler, e)
        :playlist_changed ->
          GenEvent.notify(handler, {e, new_ps})
        :player_changed ->
          GenEvent.notify(handler, {e, new_ps})
        :mixer_changed ->
          GenEvent.notify(handler, {e, new_ps})
        :outputs_changed ->
          GenEvent.notify(handler, {e, new_ps})
        :options_changed ->
          GenEvent.notify(handler, {e, new_ps})
        :sticker_changed ->
          GenEvent.notify(handler, e)
        :subscription_changed ->
          GenEvent.notify(handler, {e, MpdClient.Channels.all()})
        :message_changed ->
          {:ok, messages} = MpdClient.Channels.messages()
          GenEvent.notify(handler, {e, messages})
      end
    end)
    {:noreply, {new_ps, handler}}
  end


  def handle_call(:current_song, _from, state = {%PlayerState{:current_song => song}, _}) do
    {:reply, song, state}
  end

  def handle_call(:audio_outputs, _from, state = {%PlayerState{:outputs => outputs}, _}) do
    {:reply, outputs, state}
  end

  def handle_call(:queue, _from, state = {%PlayerState{:playlist => queue}, _}) do
    {:reply, queue, state}
  end

  def handle_call(:status, _from, state = {%PlayerState{:status => status}, _}) do
    {:reply, status, state}
  end

end
