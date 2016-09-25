defmodule Paracusia.MpdClient do
  require Logger
  use GenServer
  alias Paracusia.MessageParser
  alias Paracusia.PlayerState
  alias Paracusia.ConnectionState, as: ConnState
  import Paracusia.MessageParser, only: [string_to_boolean: 1, boolean_to_binary: 1]

  # TODO consistency: Make sure that all public functions return {:ok, _} or :{error, _}
  ## Client API

  @doc """
  Connect to the MPD server.
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Returns the current playlist.
  """
  @spec playlistinfo() :: {:ok, map} | {:error, {String.t, String.t}}
  def playlistinfo do
    GenServer.call(__MODULE__, :playlistinfo)
  end

  @doc"""
  Begins playing the playlist at song number songpos.
  """
  @spec play(integer | String.t) :: :ok | {:error, {String.t, String.t}}
  def play(songpos) do
    GenServer.call(__MODULE__, {:send_and_ack, "play #{songpos}\n"})
  end

  @doc"""
  Continues playing the current song.
  """
  @spec play() :: :ok | {:error, {String.t, String.t}}
  def play do
    GenServer.call(__MODULE__, {:send_and_ack, "play\n"})
  end

  @doc"""
  Begins playing the playlist at song songid.
  """
  @spec playid(String.t) :: :ok | {:error, {String.t, String.t}}
  def playid(songid) do
    GenServer.call(__MODULE__, {:send_and_ack, "playid #{songid}\n"})
  end

  @doc"""
  Continues playing the current song.
  """
  # TODO what is the difference to play/0?
  @spec playid() :: :ok | {:error, {String.t, String.t}}
  def playid() do
    GenServer.call(__MODULE__, {:send_and_ack, "playid\n"})
  end

  @doc"""
  Plays next song in the playlist.
  """
  @spec next() :: :ok | {:error, {String.t, String.t}}
  def next do
    GenServer.call(__MODULE__, {:send_and_ack, "next\n"})
  end

  @doc"""
  Plays previous song in the playlist.
  """
  @spec previous() :: :ok | {:error, {String.t, String.t}}
  def previous do
    GenServer.call(__MODULE__, {:send_and_ack, "previous\n"})
  end

  @doc"""
  Stops playing.
  """
  @spec stop() :: :ok | {:error, {String.t, String.t}}
  def stop do
    GenServer.call(__MODULE__, {:send_and_ack, "stop\n"})
  end

  @doc"""
  Toggles pause/resumes playing.
  """
  @spec pause(true | false) :: :ok | {:error, {String.t, String.t}}
  def pause(true), do:
    GenServer.call(__MODULE__, {:send_and_ack, "pause 1\n"})
  def pause(false), do:
    GenServer.call(__MODULE__, {:send_and_ack, "pause 0\n"})

  @doc"""
  Remove the song at position `pos` from the playlist.
  """
  @spec delete(integer | String.t) :: :ok | {:error, {String.t, String.t}}
  def delete(pos) do
    GenServer.call(__MODULE__, {:send_and_ack, "delete #{pos}\n"})
  end

  @doc"""
  Deletes all songs from `start` up to `until`, excluding `until`. Indexing starts at zero.
  """
  @spec delete(integer, integer) :: :ok | {:error, {String.t, String.t}}
  def delete(start, until) do
    GenServer.call(__MODULE__, {:send_and_ack, "delete #{start}:#{until}\n"})
  end

  @doc"""
  Deletes the song with the given id from the playlist.
  """
  @spec deleteid(integer | String.t) :: :ok | {:error, {String.t, String.t}}
  def deleteid(song_id) do
    GenServer.call(__MODULE__, {:send_and_ack, "deleteid #{song_id}\n"})
  end

  @doc"""
  Sets repeat state to true or false.
  """
  @spec repeat(boolean) :: :ok | {:error, {String.t, String.t}}
  def repeat(state) do
    msg = "repeat #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  @doc"""
  Sets random state to true or false.
  """
  @spec random(boolean) :: :ok | {:error, {String.t, String.t}}
  def random(state) do
    msg = "random #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  @doc"""
  Sets single state to true or false.
  """
  @spec single(boolean) :: :ok | {:error, {String.t, String.t}}
  def single(state) do
    msg = "single #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  @doc"""
  Sets consume state to true or false.
  """
  @spec consume(boolean) :: :ok | {:error, {String.t, String.t}}
  def consume(state) do
    msg = "consume #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  @doc"""
  Sets crossfading between songs.
  """
  @spec crossfade(integer) :: :ok | {:error, {String.t, String.t}}
  def crossfade(seconds) do
    GenServer.call(__MODULE__, {:send_and_ack, "crossfade #{seconds}\n"})
  end

  @doc"""
  Sets the threshold at which songs will be overlapped. Like crossfading but doesn't fade the track
  volume, just overlaps. The songs need to have MixRamp tags added by an external tool. 0dB is the
  normalized maximum volume so use negative values. In the absence of mixramp tags, crossfading will
  be used.
  """
  @spec mixrampdb(integer) :: :ok | {:error, {String.t, String.t}}
  def mixrampdb(decibels) do
    GenServer.call(__MODULE__, {:send_and_ack, "mixrampdb #{decibels}\n"})
  end

  @doc"""
  Sets the replay gain mode. Changing the mode during playback may take several seconds, because the
  new settings does not affect the buffered data.
  """
  @spec replay_gain_mode(:off | :track | :album | :auto) :: :ok | {:error, {String.t, String.t}}
  def replay_gain_mode(:off), do:
    GenServer.call(__MODULE__, {:send_and_ack, "replay_gain_mode off\n"})
  def replay_gain_mode(:track), do:
    GenServer.call(__MODULE__, {:send_and_ack, "replay_gain_mode track\n"})
  def replay_gain_mode(:album), do:
    GenServer.call(__MODULE__, {:send_and_ack, "replay_gain_mode album\n"})
  def replay_gain_mode(:auto), do:
    GenServer.call(__MODULE__, {:send_and_ack, "replay_gain_mode auto\n"})

  @doc"""
  Prints replay gain options. Currently, only the variable replay_gain_mode is returned.
  """
  @spec replay_gain_status() :: {:ok, String.t} | {:error, {String.t, String.t}}
  def replay_gain_status, do:
    GenServer.call(__MODULE__, {:send_and_recv, "replay_gain_status\n"})

  @doc"""
  Changes volume by amount CHANGE.
  Note: volume is deprecated, use setvol instead.
  """
  @spec volume(integer) :: :ok | {:error, {String.t, String.t}}
  def volume(change), do:
    GenServer.call(__MODULE__, {:send_and_ack, "volume #{change}\n"})

  @doc"""
  Given a query in the format "{TYPE} {WHAT} [...]", find songs in the db that are exactly WHAT.
  TYPE can be any tag supported by MPD as well as 'any', 'file', 'base' and 'modified-since'.
  See https://musicpd.org/doc/protocol/database.html for details.
  Users are advised to use the Paracusia.Query.query macro instead.
  """
  def find(query) do
    GenServer.call(__MODULE__, {:find, query})
  end

  @doc"""
  Given a query in the format "{TYPE} {WHAT} [...]", find songs in the db that are exactly WHAT and
  adds them to current playlist. Parameters have the same meaning as for find.
  See https://musicpd.org/doc/protocol/database.html for details.
  Users are advised to use the Paracusia.Query.query macro instead.
  """
  def findadd(query) do
    GenServer.call(__MODULE__, {:findadd, query})
  end

  @doc"""
  Given a query in the format "{TYPE} [FILTERTYPE] [FILTERWHAT] [...] [group] [GROUPTYPE] [...]",
  list unique tags values of the specified type. TYPE can be any tag supported by MPD or file.
  Additional arguments may specify a filter like the one in the find command. The group keyword may
  be used (repeatedly) to group the results by one or more tags.
  Note that unlike other functions, 'list' returns the string as delivered by MPD, i.e., it is not
  parsed and converted into a map.
  See https://musicpd.org/doc/protocol/database.html for details.
  """
  def list(query) do
    GenServer.call(__MODULE__, {:list, query})
  end

  @doc"""
  Lists all songs and directories in URI. Usage of the 'listll' command is discouraged by the author
  of MPD. See https://musicpd.org/doc/protocol/database.html for details.
  Returns a string of tuples, where the first entry is the property (e.g. "file"), the second entry
  is the corresponding value.
  """
  def listall(uri) do
    GenServer.call(__MODULE__, {:listall, uri})
  end

  @doc"""
  Given a query in the format "{TAG} {NEEDLE} [...] [group] [GROUPTYPE]", count the number of songs
  and their total playtime in the db matching the given tag exactly. The group keyword may be used
  to group the results by a tag.
  See https://musicpd.org/doc/protocol/database.html for details.
  Users are advised to use the Paracusia.Query.query macro instead.
  """
  def count(query) do
    GenServer.call(__MODULE__, {:count, query})
  end

  @doc"""
  Returns the current status of the player and the volume level.
  """
  @spec status() :: {:ok, %Paracusia.PlayerState.Status{}} | {:error, {String.t, String.t}}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc"""
  Returns statistics.
  """
  @spec stats() :: {:ok, %Paracusia.PlayerState.Stats{}} | {:error, {String.t, String.t}}
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc"""
  Returns the contents of the directory `uri`.
  """
  @spec lsinfo(String.t) :: {:ok, map} | {:error, {String.t, String.t}}
  def lsinfo(uri) do
    GenServer.call(__MODULE__, {:lsinfo, uri})
  end

  @doc"""
  Updates the music database. `uri` is a particular directory or song/file to update.
  Returns the job id of the update job.
  """
  @spec update(String.t) :: {:ok, integer} | {:error, {String.t, String.t}}
  def update(uri) do
    GenServer.call(__MODULE__, {:update, uri})
  end

  @doc"""
  Updates the entire music database (i.e., not restricted to a given uri).
  Returns the job id of the update job.
  """
  @spec update() :: {:ok, integer} | {:error, {String.t, String.t}}
  def update() do
    GenServer.call(__MODULE__, :update)
  end

  @spec add(String.t) :: :ok | {:error, {String.t, String.t}}
  def add(uri) do
    GenServer.call(__MODULE__, {:add, uri})
  end

  @spec comment_property(String.t) :: :ok | {:error, {String.t, String.t}}
  def comment_property(uri) do
    GenServer.call(__MODULE__, {:comment_property, uri})
  end

  @doc"""
  Returns a map that contains, at the minimum, the following keys: file, Pos and Id.
  """
  def current_song do
    GenServer.call(__MODULE__, :current_song)
  end

  @spec seek_to_percent(integer) :: :ok | {:error, {String.t, String.t}}
  def seek_to_percent(percent) do
    GenServer.call(__MODULE__, {:seek_to_percent, percent})
  end

  @spec seek(integer) :: :ok | {:error, {String.t, String.t}}
  def seek(seconds) do
    GenServer.call(__MODULE__, {:seek, seconds})
  end

  def playlist_state do
    # Caution: the status record will contain obsolete information (i.e., "elapsed" and "time").
    # Should get the new status via "status" instead, which calls the socket.
    GenServer.call(__MODULE__, :playlist_state)
  end

  @doc"""
  Sets the volume. Volume must be between 0 and 100.
  """
  @spec setvol(integer) :: :ok | {:error, {String.t, String.t}}
  def setvol(volume) do
    GenServer.call(__MODULE__, {:setvol, volume})
  end

  @doc"""
  Returns a map containing information about all audio outputs.
  """
  def outputs do
    GenServer.call(__MODULE__, :outputs)
  end

  @doc"""
  Turns an output off.
  """
  @spec disableoutput(integer) :: :ok | {:error, {String.t, String.t}}
  def disableoutput(id) do
    GenServer.call(__MODULE__, {:send_and_ack, "disableoutput #{id}\n"})
  end

  @doc"""
  Turns an output on.
  """
  @spec enableoutput(integer) :: :ok | {:error, {String.t, String.t}}
  def enableoutput(id) do
    GenServer.call(__MODULE__, {:send_and_ack, "enableoutput #{id}\n"})
  end

  @doc"""
  Turns an output on or off, depending on the current state.
  """
  @spec toggleoutput(integer) :: :ok | {:error, {String.t, String.t}}
  def toggleoutput(id) do
    GenServer.call(__MODULE__, {:send_and_ack, "toggleoutput #{id}\n"})
  end

  def debug(data) do
    GenServer.call(__MODULE__, {:debug, data})
  end

  @spec recv_until_newline(port, String.t) :: String.t
  defp recv_until_newline(sock, prev_answer \\ "") do
    answer = case :gen_tcp.recv(sock, 0) do
      {:ok, m} -> prev_answer <> m
    end
    if answer |> String.ends_with?("\n") do
      answer
    else
      recv_until_newline(sock, answer)
    end
  end

  @spec recv_until_ok(port, String.t) :: {:ok, String.t} | {:error, {String.t, String.t}}
  defp recv_until_ok(sock, prev_answer \\ "") do
    complete_msg = recv_until_newline(sock, prev_answer)
    if complete_msg |> String.ends_with?("OK\n") do
      {:ok, complete_msg |> String.trim_trailing("OK\n")}
    else
      case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, [capture: :all_but_first]) do
        [errorcode, command, message] ->
          {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
        nil ->
          recv_until_ok(sock, complete_msg)
      end
    end
  end

  @doc"""
  Lists all existing uris.
  """
  def list_uris do
    list_uris("")
  end

  @doc"""
  Lists all uris inside the directory.
  """
  def list_uris(directory) do
    _ = Logger.info "list uris for uri #{directory}"
    with {:ok, items} <- lsinfo(directory) do
      items |> Enum.flat_map(fn item ->
        case {item["file"], item["directory"]} do
          {nil, nil}  -> raise "Expected map to contain either file, or directory."
          {file, nil} -> [file]
          {nil, dir}  -> list_uris(dir)
          {_, _}      -> raise "Expected map to contain either file, or directory (not both)."
        end
      end)
    end
  end


  ## Server Callbacks

  def init([]) do
    # TODO if MPD_HOST is an absolute path, we should attempt to connect to a unix domain socket.
    {hostname, password} = case System.get_env("MPD_HOST") do
      nil -> {'localhost', nil}
      hostname -> case String.split(hostname, "@") do
        [hostname] -> {to_charlist(hostname), nil}
        [password, hostname] -> {to_charlist(hostname), password}
      end
    end
    port = case System.get_env("MPD_PORT") do
      nil -> 6600
      port -> case Integer.parse(port) do
        {p, ""} -> p
      end
    end
    {:ok, sock_passive} = :gen_tcp.connect(hostname, port, [:binary, active: false])
    {:ok, sock_active}  = :gen_tcp.connect(hostname, port, [:binary, active: :false])
    "OK MPD" <> _ = recv_until_newline(sock_passive)
    "OK MPD" <> _ = recv_until_newline(sock_active)
    if password do
      :ok = :gen_tcp.send(sock_active, "password #{password}\n")
      :ok = :gen_tcp.send(sock_passive, "password #{password}\n")
      :ok = ok_from_socket(sock_passive)
      :ok = ok_from_socket(sock_active)
    end
    :ok = :gen_tcp.send(sock_active, "idle\n")
    :ok = :inet.setopts(sock_active, [active: :once])
    {:ok, genevent_pid} = GenEvent.start_link()
    case Application.get_env(:paracusia, :event_handler) do
      nil ->
        :ok = GenEvent.add_handler(genevent_pid, Paracusia.DefaultEventHandler, nil)
      event_handler ->
        :ok = GenEvent.add_handler(genevent_pid, event_handler, nil)
    end
    {:ok, _} = :timer.send_interval(6000, :send_ping)
    {:ok, current_song} = current_song_from_socket(sock_passive)
    {:ok, playlist} = playlist_from_socket(sock_passive)
    {:ok, status} = status_from_socket(sock_passive)
    {:ok, outputs} = outputs_from_socket(sock_passive)
    mpd_state = %PlayerState{current_song: current_song,
                             playlist: playlist,
                             status: status,
                             outputs: outputs}
    _ = Logger.info "initial mpd state is: #{inspect mpd_state}"
    conn_state = %ConnState{:sock_passive => sock_passive,
                            :sock_active => sock_active,
                            :genevent_pid => genevent_pid,
                            :status => :new}
    {:ok, {mpd_state, conn_state}}
  end

  def player_state do
    GenServer.call(__MODULE__, :player_state)
  end

  defp read_until_next_newline(socket, prev_msg) do
    case :gen_tcp.recv(socket, 1) do
      {:ok, "\n"} -> prev_msg <> "\n"
      {:ok, msg}  -> read_until_next_newline(socket, prev_msg <> msg)
    end
  end

  defp ok_from_socket(socket) do
    case :gen_tcp.recv(socket, 3) do
      {:ok, "OK\n"} -> :ok
      {:ok, "ACK"} ->
        complete_msg = read_until_next_newline(socket, "ACK")
        case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, [capture: :all_but_first]) do
          [errorcode, command, message] ->
            {:error, {errorcode,
              "error #{errorcode} while executing command #{command}: #{message}"}}
        end
    end
  end

  @spec playlist_from_socket(port) :: {:ok, [map]} | {:error, String.t}
  defp playlist_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "playlistinfo\n")
    with {:ok, reply} <- recv_until_ok(socket) do
      {:ok, Paracusia.MessageParser.songs(reply)}
    end
  end

  defp status_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "status\n")
    with {:ok, m} <- recv_until_ok(socket) do
      status = MessageParser.parse_newline_separated(m)
      nil_or_else = fn(x, f) ->
        case x do
          nil -> nil
          x -> f.(x)
        end
      end
      timestamp = case :erlang.timestamp do
        {megasecs, secs, microsecs} ->
          megasecs * 1000000000000 + secs * 1000000 + microsecs
      end
      {:ok, %PlayerState.Status{
        :volume => String.to_integer(status["volume"]),
        :repeat => string_to_boolean(status["repeat"]),
        :random => string_to_boolean(status["random"]),
        :single => string_to_boolean(status["single"]),
        :consume => string_to_boolean(status["consume"]),
        :playlist => String.to_integer(status["playlist"]),
        :playlistlength => String.to_integer(status["playlistlength"]),
        :state => case status["state"] do
                    "play" -> :play
                    "stop" -> :stop
                    "pause" -> :pause
                  end,
        :song => status["song"] |> nil_or_else.(&String.to_integer(&1)),
        :songid => status["songid"] |> nil_or_else.(&String.to_integer(&1)),
        :nextsong => status["nextsong"] |> nil_or_else.(&String.to_integer(&1)),
        :time => status["time"],
        :elapsed => status["elapsed"] |> nil_or_else.(&String.to_float(&1)),
        :duration => status["duration"],
        :bitrate => status["bitrate"] |> nil_or_else.(&String.to_integer(&1)),
        :xfade => status["xfade"] |> nil_or_else.(&String.to_integer(&1)),
        :mixrampdb => status["mixrampdb"] |> nil_or_else.(&String.to_float(&1)),
        :mixrampdelay => status["mixrampdelay"] |> nil_or_else.(&String.to_integer(&1)),
        :audio => status["audio"]
                |> nil_or_else.(&Regex.run(~r/(.*):(.*):(.*)/, &1, [capture: :all_but_first])),
        :updating_db => status["updating_db"] |> nil_or_else.(&String.to_integer(&1)),
        :error => status["error"],
        :timestamp => timestamp
      }}
    end
  end

  defp current_song_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "currentsong\n")
    with {:ok, answer} <- recv_until_ok(socket) do
      {:ok, MessageParser.current_song(answer)}
    end
  end

  ## See https://www.musicpd.org/doc/protocol/command_reference.html
  ## for an overview of all idle commands.

  defp process_message(msg, genevent_pid) do
    process_message(msg, genevent_pid, [])
  end

  defp process_message("changed: database\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:database_changed | events])
  end

  defp process_message("changed: update\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:update_changed | events])
  end

  defp process_message("changed: stored_playlist\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:stored_playlist_changed | events])
  end

  defp process_message("changed: playlist\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:playlist_changed | events])
  end

  defp process_message("changed: player\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:player_changed | events])
  end

  defp process_message("changed: mixer\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:mixer_changed | events])
  end

  defp process_message("changed: output\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:outputs_changed | events])
  end

  defp process_message("changed: options\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:options_changed | events])
  end

  defp process_message("changed: sticker\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:sticker_changed | events])
  end

  defp process_message("changed: subscription\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:subscription_changed | events])
  end

  defp process_message("changed: message\n" <> rest, genevent_pid, events) do
    process_message(rest, genevent_pid, [:message_changed | events])
  end

  defp process_message("OK\n", _, events) do
    events
  end

  defp new_ps_from_events(ps, events, socket) do
    new_outputs = if Enum.member?(events, :outputs_changed) do
      outputs_from_socket(socket)
    else
      ps.outputs
    end
    new_current_song = if Enum.member?(events, :player_changed) do
      case current_song_from_socket(socket) do
        {:ok, song} -> song
      end
    else
      ps.current_song
    end
    new_playlist = if Enum.member?(events, :playlist_changed) do
      {:ok, playlist} = playlist_from_socket(socket)
      playlist
    else
      ps.playlist
    end
    status_changed = Enum.any?([:mixer_changed, :player_changed, :options_changed], fn subsystem ->
      Enum.member?(events, subsystem)
    end)
    new_status = if status_changed do
      case status_from_socket(socket) do
        {:ok, status} -> status
      end
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

  defp seek_to_seconds(socket, seconds) do
    :ok = :gen_tcp.send(socket, "seekcur #{seconds}\n")
    ok_from_socket(socket)
  end

  defp outputs_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "outputs\n")
    with {:ok, m} <- recv_until_ok(socket) do
      {:ok, MessageParser.parse_outputs(m)}
    end
  end

  def handle_call({:lsinfo, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "lsinfo \"#{uri}\"\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, MessageParser.parse_items(m)}
    end
    {:reply, answer, state}
  end

  def handle_call(:update, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "update\n")
    answer = with {:ok, "updating_db: " <> rest} <- recv_until_ok(cs.sock_passive) do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer
      {:ok, job_id}
    end
    {:reply, answer, state}
  end

  def handle_call({:update, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "update \"#{uri}\"\n")
    answer = with {:ok, "updating_db: " <> rest} <- recv_until_ok(cs.sock_passive) do
      job_id = rest |> String.replace_suffix("\n", "") |> String.to_integer
      {:ok, job_id}
    end
    {:reply, answer, state}
  end

  def handle_call({:find, query}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "find #{query}\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, MessageParser.parse_newline_separated(m)}
    end
    {:reply, answer, state}
  end

  def handle_call({:findadd, query}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "findadd #{query}\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, MessageParser.parse_newline_separated(m)}
    end
    {:reply, answer, state}
  end

  def handle_call({:list, query}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "list #{query}\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, m}
    end
    {:reply, answer, state}
  end

  def handle_call({:listall, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "listall #{uri}\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, MessageParser.parse_uris(m)}
    end
    {:reply, answer, state}
  end

  def handle_call({:count, query}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "count #{query}\n")
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      {:ok, MessageParser.parse_newline_separated(m)}
    end
    {:reply, answer, state}
  end

  def handle_call({:add, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "add \"#{uri}\"\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:debug, data}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, data)
    {:ok, answer} = recv_until_ok(cs.sock_passive)
    {:reply, answer, state}
  end

  def handle_call(:playlistinfo, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    answer = playlist_from_socket(cs.sock_passive)
    {:reply, answer, state}
  end

  def handle_call(:status, _from, state = {%PlayerState{}, cs = %ConnState{}}) do
    answer = status_from_socket(cs.sock_passive)
    {:reply, answer, state}
  end

  def handle_call(:stats, _from, state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "stats\n")
    answer = with {:ok, reply} <- recv_until_ok(cs.sock_passive) do
      string_map = reply |> MessageParser.parse_newline_separated
      answer = %PlayerState.Stats{
        artists: String.to_integer(string_map["artists"]),
        albums: String.to_integer(string_map["albums"]),
        songs: String.to_integer(string_map["songs"]),
        uptime: String.to_integer(string_map["uptime"]),
        db_playtime: String.to_integer(string_map["db_playtime"]),
        db_update: String.to_integer(string_map["db_update"]),
        playtime: String.to_integer(string_map["playtime"])
      }
    end
    {:reply, answer, state}
  end

  def handle_call({:comment_property, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "readcomments \"#{uri}\"\n")
    answer = with {:ok, reply} <- recv_until_ok(cs.sock_passive) do
      lines = case reply |> String.trim_trailing("\n") |> String.split("\n") do
        [""] -> []  # map over empty sequence if server has replied with newline
        x    -> x
      end
      lines |> Enum.reduce(%{}, fn (line, acc) ->
        case String.split(line, ": ", parts: 2) do
          [key, val] -> Map.put(acc, key, val)
        end
      end)
    end
    {:reply, answer, state}
  end

  def handle_call(:current_song, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    {:reply, current_song_from_socket(cs.sock_passive), state}
  end

  def handle_call(:playlist_state, _from, state = {ps = %PlayerState{}, _}) do
    {:reply, ps, state}
  end

  def handle_call({:setvol, volume}, _from, state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "setvol #{volume}\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:outputs, _from, state = {%PlayerState{}, cs = %ConnState{}}) do
    reply = outputs_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:send_and_ack, msg}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, msg)
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:send_and_recv, msg}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, msg)
    reply = recv_until_ok(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:seek_to_percent, percent}, _from,
                  state = {ps = %PlayerState{}, cs = %ConnState{}}) do
    duration = ps.current_song["Time"] |> String.to_integer
    secs = duration * (percent/100)
    answer = seek_to_seconds(cs.sock_passive, secs)
    {:reply, answer, state}
  end

  def handle_call({:seek, seconds}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    answer = seek_to_seconds(cs.sock_passive, seconds)
    {:reply, answer, state}
  end

  def handle_call(:player_state, _from,
                  state = {ps = %PlayerState{}, %ConnState{}}) do
    {:reply, ps, state}
  end

  def handle_info(:send_ping, state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "ping\n")
    :ok = ok_from_socket(cs.sock_passive)
    {:noreply, state}
  end

  def handle_info({:tcp, _, msg},
                  {ps = %PlayerState{}, cs = %ConnState{:status => :new}}) do
    _ = Logger.info "msg from mpd: >#{msg}<"
    complete_msg =
      if String.ends_with?(msg, "OK\n") do
        msg
      else
        case recv_until_ok(cs.sock_active, msg) do
          {:ok, without_trailing_ok} -> without_trailing_ok <> "OK\n"
        end
      end
    events = process_message(complete_msg, cs.genevent_pid)
    new_ps = new_ps_from_events(ps, events, cs.sock_passive)
    Enum.each(events, &(GenEvent.notify(cs.genevent_pid, {&1, new_ps})))
    _ = Logger.info "Received the following idle events: #{inspect events}"
    # We have received this message as a result of having sent idle. We need to resend idle
    # each time after we have obtained a new idle message.
    :ok = :gen_tcp.send(cs.sock_active, "idle\n")
    :ok = :inet.setopts(cs.sock_active, [active: :once])
    {:noreply, {new_ps, cs}}
  end

end
