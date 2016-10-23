# Paracusia

Paracusia is an MPD client library for Elixir.

## Installation

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
If MPD runs on localhost and the standard port 6600 without password authorization, no further
configuration is required.  Otherwise, the environment variables MPD\_HOST and MPD\_PORT can be set.
Just like with the command line application mpc, a password may be provided by setting MPD\_HOST to
"password@host".  Alternatively, users may set the application variables `hostname`, `password` and
`port` in the configuration file:
    ```elixir
    config :paracusia,
      hostname: "192.168.1.5",
      password: "topsecret",
      port: 6696
    ```
Omit the password if no password authorization is required. Application variables take precedence
over environment variables, i.e., environment variables are used as fallback in case the application
variables are not specified.  Once the MPD credentials are configured, you may continue to start
your application and control MPD.
For instance, to play the first song in the current playlist:

## Usage

To play the first song in the current playlist:
```elixir
:ok = Paracusia.MpdClient.Playback.play_pos(0)
```
To obtain all files and directories in MPD's root directory:
```elixir
{:ok, uris} = Paracusia.MpdClient.Database.lsinfo("")
```
Note that all functions of all submodules of Paracusia.MpdClient always return `:ok` or `{:ok,
result}` if everything went well, or `{:error, {errorcode, description}}` otherwise. For instance,
if we choose a number that is larger than our current playlist and try to play it, MPD refuses to do
so and instead warns us that the song index is invalid:
```elixir
Paracusia.MpdClient.play(999)
{:error, {"2@0", "error 2@0 while executing command play: Bad song index"}}
```

You may also have noted logging messages to appear once we play an existing
song. This is due to the GenEvent handler named `Paracusia.DefaultEventHandler`,
which is used if you have not specified your own event handler. An event is
emitted when one of MPD's subsystems changes, see the
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
Once we have made these changes, we need to install our event handler: Open the config file and add
the event handler as well as the initial state, for example:
```elixir
config :paracusia,
  event_handler: MyProject.MyEventHandler,
  initial_state: []
```

## Bugs and general Feedback

Please open an issue in case you find any bugs, have any questions or want to
suggest improvements.
