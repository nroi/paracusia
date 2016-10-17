# Paracusia

Paracusia is an MPD client library. It's written entirely in Elixir, without any
dependencies outside the standard library.
Paracusia not only exposes the API calls for a running MPD server, but also
maintains state. This means you can access properties of MPD (such as the
currently playing song) without sending a new message over the socket.

## Current status
alpha. Bugs are likely to occur, the API is subject to change.

## Installation

**TODO: Publish on hex**

  1. Add `paracusia` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:paracusia, "~> 0.1.0"}]
    end
    ```

  2. Ensure `paracusia` is started before your application:

    ```elixir
    def application do
      [applications: [:paracusia]]
    end
    ```

You can now continue to use most of the commands listed in the MPD protocol
specification (some of them are not implemented yet). For instance, to obtain
all files and directories in MPD's root directory:
```elixir
{:ok, uris} = Paracusia.MpdClient.lsinfo("")
```
To play the first song in the current playlist:
```elixir
:ok = Paracusia.MpdClient.play(0)
```
Note that functions which are directly related to an MPD command always return
`:ok` or `{:ok, result}` if everything went well, or `{:error, {errorcode,
description}}` otherwise. For instance, choose an arbitrary number that is
larger than your current playlist and try to play it:
```
Paracusia.MpdClient.play(999)
{:error, {"2@0", "error 2@0 while executing command play: Bad song index"}}
```

You may also have noted logging messages to appear once we play an existing
song. This is due to the GenEvent handler named `Paracusia.DefaultEventHandler`,
which is used if you have not specified your own event handler. An event is
emitted when one of MPD's subsystem changes, see the
[idle](https://musicpd.org/doc/protocol/command_reference.html#status_commands)
command for more details on which changes are associated with which subsystems.
To use your own event handler, you can copy the file
`lib/paracusia/default_event_handler.ex` into your own project, rename it as
desired and implement your own callbacks. As an example, let's show the
currently playing song whenever it changes. As mentioned in the MPD protocol
specification, the 'player' subsystem changes after seeking, starting or
stopping the player, so we need to change the handle\_event clause for the
`:player_changed` atom:

```elixir
  def handle_event({:player_changed, ps = %PlayerState{}}, state = nil) do
    _ = Logger.info "new song: #{inspect ps.current_song}"
    {:ok, state}
  end
```
Once we have made these changes, we need to install our event handler: Open the
config file `config/config.exs` and the event handler as well as the initial
state, for example:
```elixir
config :paracusia,
  event_handler: MyProject.MyEventHandler,
  initial_state: []
```
