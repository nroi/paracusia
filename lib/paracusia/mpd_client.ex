defmodule Paracusia.MpdClient do
  require Logger
  use GenServer
  alias Paracusia.MessageParser
  alias Paracusia.PlayerState
  alias Paracusia.ConnectionState, as: ConnState

  # TODO MPD uses "OK\n" as message separator. Can this cause problems when we have e.g. songs named
  # "OK", in the sense that the name is confused with the message separator?

  ## Client API

  @doc """
  Connect to the MPD server.
  """
  def start_link(handler) do
    # ignore version info from mpd server
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Returns the current playlist.
  """
  def playlistinfo do
    GenServer.call(__MODULE__, :playlistinfo)
  end

  def play(song_id) do
    GenServer.call(__MODULE__, {:play, song_id})
  end

  def play do
    GenServer.call(__MODULE__, :play)
  end

  def next do
    GenServer.call(__MODULE__, :next)
  end

  def previous do
    GenServer.call(__MODULE__, :previous)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  def pause do
    GenServer.call(__MODULE__, :pause)
  end

  def delete(song_id) do
    GenServer.call(__MODULE__, {:delete, song_id})
  end

  def repeat(state) do
    msg = "repeat #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  def random(state) do
    msg = "random #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  def single(state) do
    msg = "single #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  def consume(state) do
    msg = "consume #{boolean_to_binary(state)}\n"
    GenServer.call(__MODULE__, {:send_and_ack, msg})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def debug(data) do
    GenServer.call(__MODULE__, {:debug, data})
  end

  def lsinfo(uri) do
    GenServer.call(__MODULE__, {:lsinfo, uri})
  end

  def add(uri) do
    GenServer.call(__MODULE__, {:add, uri})
  end

  def comment_property(uri) do
    GenServer.call(__MODULE__, {:comment_property, uri})
  end

  @doc"""
  Returns a map that contains, at the minimum, the following keys: file, Pos and Id.
  """
  def current_song do
    GenServer.call(__MODULE__, :current_song)
  end

  def seek_to_percent(percent) do
    GenServer.call(__MODULE__, {:seek_to_percent, percent})
  end

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
  def setvol(volume) do
    GenServer.call(__MODULE__, {:setvol, volume})
  end

  defp boolean_to_binary(false), do: 0
  defp boolean_to_binary(true), do: 1
  defp string_to_boolean("0"), do: false
  defp string_to_boolean("1"), do: true

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

  defp recv_until_ok(sock, prev_answer \\ "") do
    complete_msg = recv_until_newline(sock, prev_answer)
    if complete_msg |> String.ends_with?("OK\n") do
      {:ok, complete_msg |> String.trim_trailing("OK\n")}
    else
      case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)/, complete_msg, [capture: :all_but_first]) do
        [errorcode, command, message] ->
          # note that some errors are harmless, e.g. when a file contained in the database is
          # deleted, running commands such as readcomments will fail. Hence, we just log the error
          # instead of crashing.
          _ = Logger.warn "error #{errorcode} while executing command #{command}: #{message}"
          :error
        nil ->
          recv_until_ok(sock, complete_msg)
      end
    end
  end

  def list_uris do
    list_uris("")
  end
  def list_uris(path) do
    _ = Logger.info "list uris for path #{path}"
    lsinfo(path) |> Enum.flat_map(fn item ->
      case item do
        [{"directory", dir} | _] -> list_uris(dir)
        [{"file", file} | _] -> [file]
      end
    end)
  end


  ## Server Callbacks

  def init([]) do
    # TODO if MPD_HOST is an absolute path, we should attempt to connect to a unix domain socket.
    {hostname, password} = case System.get_env("MPD_HOST") do
      nil -> {'localhost', nil}
      hostname -> case String.split(hostname, "@") do
        [hostname] -> to_charlist hostname
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
    :ok = :gen_tcp.send(sock_active, "password #{password}\n")
    :ok = :gen_tcp.send(sock_passive, "password #{password}\n")
    :ok = ok_from_socket(sock_passive)
    :ok = ok_from_socket(sock_active)
    :ok = :gen_tcp.send(sock_active, "idle\n")
    :ok = :inet.setopts(sock_active, [active: :once])
    {:ok, genevent_pid} = GenEvent.start_link()
    event_handler = Application.get_env(:paracusia, :event_handler)
    :ok = GenEvent.add_handler(genevent_pid, event_handler, nil)
    {:ok, _} = :timer.send_interval(6000, :send_ping)
    mpd_state = %PlayerState{current_song: current_song_from_socket(sock_passive),
                             playlist: playlist_from_socket(sock_passive),
                             status: status_from_socket(sock_passive)}
    _ = Logger.info "initial mpd state is: #{inspect mpd_state}"
    conn_state = %ConnState{:sock_passive => sock_passive,
                            :sock_active => sock_active,
                            :genevent_pid => genevent_pid,
                            :status => :new}
    {:ok, {mpd_state, conn_state}}
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
            {:error, {errorcode, "error #{errorcode} while executing command #{command}: #{message}"}}
        end
    end
  end

  defp playlist_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "playlistinfo\n")
    {:ok, answer} = recv_until_ok(socket)
    Paracusia.MessageParser.songs(answer)
  end

  defp status_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "status\n")
    answer = case recv_until_ok(socket) do
      {:ok, m} -> MessageParser.parse_newline_separated(m)
    end
    _  = Logger.info "answer: #{inspect answer}"
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
    %PlayerState.Status{
      :volume => String.to_integer(answer["volume"]),
      :repeat => string_to_boolean(answer["repeat"]),
      :random => string_to_boolean(answer["random"]),
      :single => string_to_boolean(answer["single"]),
      :consume => string_to_boolean(answer["consume"]),
      :playlist => String.to_integer(answer["playlist"]),
      :playlistlength => String.to_integer(answer["playlistlength"]),
      :state => case answer["state"] do
                  "play" -> :play
                  "stop" -> :stop
                  "pause" -> :pause
                end,
      :song => answer["song"] |> nil_or_else.(&String.to_integer(&1)),
      :songid => answer["songid"] |> nil_or_else.(&String.to_integer(&1)),
      :nextsong => answer["nextsong"] |> nil_or_else.(&String.to_integer(&1)),
      :time => answer["time"],
      :elapsed => answer["elapsed"] |> nil_or_else.(&String.to_float(&1)),
      :duration => answer["duration"],
      :bitrate => answer["bitrate"] |> nil_or_else.(&String.to_integer(&1)),
      :xfade => answer["xfade"] |> nil_or_else.(&String.to_integer(&1)),
      :mixrampdb => answer["mixrampdb"] |> nil_or_else.(&String.to_float(&1)),
      :mixrampdelay => answer["mixrampdelay"] |> nil_or_else.(&String.to_integer(&1)),
      :audio => answer["audio"]
              |> nil_or_else.(&Regex.run(~r/(.*):(.*):(.*)/, &1, [capture: :all_but_first])),
      :updating_db => answer["updating_db"] |> nil_or_else.(&String.to_integer(&1)),
      :error => answer["error"],
      :timestamp => timestamp
    }
  end

  defp current_song_from_socket(socket) do
    :ok = :gen_tcp.send(socket, "currentsong\n")
    {:ok, answer} = recv_until_ok(socket)
    MessageParser.current_song(answer)
  end

  ## See https://www.musicpd.org/doc/protocol/command_reference.html
  ## for an overview of all idle commands.

  defp process_message(msg, genevent_pid) do
    process_message(msg, genevent_pid, [])
  end

  defp process_message(msg = "ACK " <> _, _genevent_pid, events) do
    _ = case Regex.run(~r/ACK \[(.*)\] {(.*)} (.*)\n/, msg, [capture: :all_but_first]) do
      [errorcode, command, message] ->
        Logger.warn "error #{errorcode} while executing command #{command}: #{message}"
     end
     events
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
    process_message(rest, genevent_pid, [:output_changed | events])
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
    new_current_song = if Enum.member?(events, :player_changed) do
      current_song_from_socket(socket)
    else
      ps.current_song
    end
    new_playlist = if Enum.member?(events, :playlist_changed) do
      playlist_from_socket(socket)
    else
      ps.playlist
    end
    status_changed = Enum.any?([:mixer_changed, :player_changed, :options_changed], fn subsystem ->
      Enum.member?(events, subsystem)
    end)
    new_status = if status_changed do
      status_from_socket(socket)
    else
      ps.status
    end
    %PlayerState{
      :current_song => new_current_song,
      :playlist => new_playlist,
      :status => new_status
    }
  end

  defp seek_to_seconds(socket, seconds, state) do
    if state == :stop do
      _ = Logger.warn "Cannot seek while player is stopped!"
    else
      :ok = :gen_tcp.send(socket, "seekcur #{seconds}\n")
      ok_from_socket(socket)
    end
  end

  def handle_call({:lsinfo, uri}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    _ = Logger.info "lsinfo #{uri}"
    :ok = :gen_tcp.send(cs.sock_passive, "lsinfo \"#{uri}\"\n")
    _ = Logger.info "done."
    answer = with {:ok, m} <- recv_until_ok(cs.sock_passive) do
      MessageParser.parse_items(m)
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
    songs = playlist_from_socket(cs.sock_passive)
    {:reply, songs, state}
  end

  def handle_call(:status, _from, state = {%PlayerState{}, cs = %ConnState{}}) do
    answer = status_from_socket(cs.sock_passive)
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

  def handle_call({:play, song_id}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "playid #{song_id}\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:play, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "play\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:next, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "next\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:previous, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "previous\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:stop, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "stop\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call(:pause, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "pause\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:delete, song_id}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, "deleteid #{song_id}\n")
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:send_and_ack, msg}, _from,
                  state = {%PlayerState{}, cs = %ConnState{}}) do
    :ok = :gen_tcp.send(cs.sock_passive, msg)
    reply = ok_from_socket(cs.sock_passive)
    {:reply, reply, state}
  end

  def handle_call({:seek_to_percent, percent}, _from,
                  state = {ps = %PlayerState{}, cs = %ConnState{}}) do
    if ps.status.state == :stop do
      _ = Logger.warn "Cannot seek while player is stopped"
      {:noreply, state}
    else
      duration = case ps.current_song do
        nil -> nil
        song -> song.duration_in_secs
      end
      IO.puts "duration: #{duration}"
      secs = duration * (percent/100)
      answer = seek_to_seconds(cs.sock_passive, secs, ps.status.state)
      {:reply, answer, state}
    end
  end

  def handle_call({:seek, seconds}, _from,
                  state = {ps = %PlayerState{}, cs = %ConnState{}}) do
    answer = seek_to_seconds(cs.sock_passive, seconds, ps.status.state)
    {:reply, answer, state}
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
