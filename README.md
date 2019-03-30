# Paracusia
[![Hex pm](https://img.shields.io/hexpm/v/paracusia.svg?style=flat)](https://hex.pm/packages/paracusia)

Paracusia is an MPD client library for Elixir.

## Installation

Add `paracusia` to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [{:paracusia, "~> 0.2.11"}]
end
```

If MPD runs on localhost and the standard port 6600 without password authorization, no further
configuration is required. Otherwise, the environment variables `MPD_HOST` and `MPD_PORT` can be set.
Just like with the command line application mpc, a password may be provided by setting `MPD_HOST` to
"password@host". Alternatively, users may set the application variables `hostname`, `password` and
`port` in the configuration file:
```elixir
config :paracusia,
  hostname: "192.168.1.5",
  password: "topsecret",
  port: 6696,
  retry_after: 100,
  max_retry_attempts: 3
```
The hostname may refer to an IPv4 address, an IPv6 address, a domain, or a file in case MPD is
accessible by a Unix domain socket. Omit the password if no password authorization is required.
Application variables take precedence over environment variables, i.e., environment variables are
used as fallback in case no application variables are specified. If at least one application
variable is defined, no environment variables will be used.
Once the MPD credentials are configured, you may continue to start
your application and control MPD.

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
Paracusia.MpdClient.Playback.play_pos(999)
{:error, {"2@0", "error 2@0 while executing command play: Bad song index"}}
```

Paracusia maintains a list of subscribers which receive a message whenever the current state of MPD changes.
Use the `Paracusia.PlayerState.subscribe/1` function to become a subscriber, for instance:
```Elixir
iex(1)> Paracusia.PlayerState.subscribe(self())
:ok
iex(2)> Paracusia.MpdClient.Playback.pause(true) # to receive some messages
iex(3)> flush()
{:paracusia,
 {:mixer_changed,
  %Paracusia.PlayerState{…}
 }
}
```

Check out
[Paracusia.DefaultEventHandler](https://github.com/nroi/paracusia/blob/master/lib/paracusia/default_event_handler.ex)
to get an overview of what messages are sent for what reasons. In general, Paracusia sends a message
whenever one of MPD's subsystems has changed. See the
[idle](https://musicpd.org/doc/protocol/command_reference.html#status_commands) command for more
details on which changes are associated with which subsystems.

## API

See the [documentation](https://hexdocs.pm/paracusia/api-reference.html) for
more details.

## Bugs and General Feedback

Please open an issue in case you find any bugs, have any questions or want to
suggest improvements.
