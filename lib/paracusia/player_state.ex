defmodule Paracusia.PlayerState do
  alias Paracusia.MpdClient
  alias Paracusia.PlayerState
  require Logger
  use GenServer

  @type t :: %PlayerState{current_song: nil | map,
                          queue: list,
                          status: %Paracusia.PlayerState.Status{},
                          outputs: list}
  defstruct current_song: nil,
            queue: [],
            status: %Paracusia.PlayerState.Status{},
            outputs: []


  @moduledoc"""
  Provides access to the current state of MPD, without having to send messages over the socket.

  All functions in this module have a pendant in a submodule of `Paracusia.MpdClient` (but not vice
  versa). Using these functions instead of the ones in `Paracusia.MpdClient` has the advantage that
  latency is lower and no superfluous TCP messages are sent.
  """


  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid) do
    GenServer.call(__MODULE__, {:unsubscribe, pid})
  end


  @doc"""
  Similar to `Paracusia.MpdClient.Status.current_song/0`, but returns `nil` if no song is available.
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
  """
  @spec status() :: %Paracusia.PlayerState.Status{}
  def status do
    GenServer.call(__MODULE__, :status)
  end


  def init(nil) do
    {:ok, current_song} = MpdClient.Status.current_song
    {:ok, queue} = MpdClient.Queue.songs_info
    {:ok, status} = MpdClient.Status.status
    {:ok, outputs} = MpdClient.AudioOutputs.all
    player_state = %PlayerState{current_song: current_song,
                                queue: queue,
                                status: status,
                                outputs: outputs}
    _ = Logger.debug "Player initialized, playback status: #{inspect player_state.status.state}"
    {:ok, {player_state, []}}
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
      ps.queue
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
      current_song: new_current_song,
      queue: new_playlist,
      status: new_status,
      outputs: new_outputs,
    }
  end

  def handle_cast({:event, e}, {ps, subscribers}) do
    new_ps = new_ps_from_events(ps, [e])
    msg = case e do
      :database_changed ->
          {:paracusia, e}
      :update_changed ->
          {:paracusia, e}
      :stored_playlist_changed ->
          {:paracusia, e}
      :playlist_changed ->
          {:paracusia, {e, new_ps}}
      :player_changed ->
          {:paracusia, {e, new_ps}}
      :mixer_changed ->
          {:paracusia, {e, new_ps}}
      :outputs_changed ->
          {:paracusia, {e, new_ps}}
      :options_changed ->
          {:paracusia, {e, new_ps}}
      :sticker_changed ->
          {:paracusia, e}
      :subscription_changed ->
          {:paracusia, {e, MpdClient.Channels.all()}}
      :message_changed ->
        {:ok, messages} = MpdClient.Channels.__messages__()
          {:paracusia, {e, messages}}
    end
    Enum.each(subscribers, fn {subscriber, _} ->
      send subscriber, msg
    end)
    {:noreply, {new_ps, subscribers}}
  end

  def handle_call(:current_song, _from, state = {%PlayerState{:current_song => song}, _}) do
    {:reply, song, state}
  end

  def handle_call(:audio_outputs, _from, state = {%PlayerState{:outputs => outputs}, _}) do
    {:reply, outputs, state}
  end

  def handle_call(:queue, _from, state = {%PlayerState{:queue => queue}, _}) do
    {:reply, queue, state}
  end

  def handle_call(:status, _from, state = {%PlayerState{:status => status}, _}) do
    {:reply, status, state}
  end

  def handle_call({:subscribe, pid}, _from, {ps, subs}) do
    ref = Process.monitor(pid)
    new_subs = [{pid,ref}|subs]
    {:reply, :ok, {ps, new_subs}}
  end

  def handle_call({:unsubscribe, pid}, _from, {ps, subs}) do
    ref = Enum.find_value(subs, fn {ppid, ref} -> ppid == pid && ref end)
    Process.demonitor(ref)
    new_subs = :lists.delete({pid,ref}, subs)
    {:reply, :ok, {ps, new_subs}}
  end

  def handle_info({:DOWN, ref, :process, pid, _status}, {ps, subs}) do
    new_subs = :lists.delete({pid,ref}, subs)
    {:noreply, {ps, new_subs}}
  end

end
