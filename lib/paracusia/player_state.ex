defmodule Paracusia.PlayerState do
  alias Paracusia.MpdClient
  alias Paracusia.PlayerState
  require Logger
  use GenServer
  defstruct current_song: nil,
            playlist: [],
            status: %Paracusia.PlayerState.Status{},
            outputs: []


  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end



  # returns the current song without sending a message over the socket.
  def current_song do
    GenServer.call(__MODULE__, :current_song)
  end


  def init(nil) do
    {:ok, current_song} = MpdClient.Status.current_song
    {:ok, playlist} = MpdClient.Queue.songs_info
    {:ok, status} = MpdClient.Status.status
    {:ok, outputs} = MpdClient.AudioOutputs.list
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
      {:ok, outputs} = MpdClient.AudioOutputs.list
      outputs
    else
      ps.outputs
    end
    new_current_song = if Enum.member?(events, :player_changed) do
      # TODO what happens if there is no current song?
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
  def handle_cast({:events, events}, {ps = %PlayerState{}, handler}) do
    _ = Logger.debug "Received the following idle events: #{inspect events}"
    new_ps = new_ps_from_events(ps, events)
    Enum.each(events, &(GenEvent.notify(handler, {&1, new_ps})))
    {:noreply, {new_ps, handler}}
  end


  def handle_call(:current_song, _form, state = {%PlayerState{:current_song => song}, handler}) do
    {:reply, song, state}
  end


end
