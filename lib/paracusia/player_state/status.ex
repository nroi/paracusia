defmodule Paracusia.PlayerState.Status do
  alias Paracusia.PlayerState.Status

  @type t :: %Status{
          volume: integer | nil,
          repeat: boolean,
          random: boolean,
          single: boolean,
          consume: boolean,
          playlist: integer | nil,
          playlist_length: integer | nil,
          state: :play | :stop | :pause,
          song_pos: integer | nil,
          song_id: integer | nil,
          next_song_pos: integer | nil,
          next_song_id: integer | nil,
          time: integer | nil,
          elapsed: integer | nil,
          bitrate: integer | nil,
          xfade: number | nil,
          mixrampdb: number | nil,
          mixrampdelay: number | nil,
          audio: [String.t()],
          updating_db: integer | nil,
          error: String.t() | nil,
          timestamp: integer
        }

  # 0-100 during play/pause, -1 if playback is stopped
  defstruct volume: -1,
            # true or false
            repeat: nil,
            # true or false
            random: nil,
            # true or false
            single: nil,
            # true or false
            consume: nil,
            # the playlist version number
            playlist: nil,
            # integer, the length of the playlist
            playlist_length: nil,
            # :play, :stop, or :pause
            state: nil,
            # playlist song number of the current song stopped on or playing
            song_pos: nil,
            # playlist songid of the current song stopped on or playing
            song_id: nil,
            # playlist song number of the next song to be played
            next_song_pos: nil,
            # playlist songid of the next song to be played
            next_song_id: nil,
            # total time elapsed (of current playing/paused song)
            time: nil,
            # like time, but with higher resolution.
            elapsed: nil,
            # instantaneous bitrate in kbps
            bitrate: nil,
            # crossfade in seconds
            xfade: nil,
            # mixramp threshold in dB
            mixrampdb: nil,
            # mixrampdelay in seconds
            mixrampdelay: nil,
            # sampleRate:bits:channels
            audio: nil,
            # job id
            updating_db: nil,
            # error message, if there is an error
            error: nil,
            # indicates when the information was retrieved (not part
            # of the MPD protocol)
            timestamp: -1
end

if Code.ensure_compiled?(Jason) do
  defimpl Jason.Encoder, for: [Paracusia.PlayerState.Status] do
    def encode(struct, opts) do
      struct
      |> Map.delete(:__struct__)
      |> Jason.Encode.map(opts)
    end
  end
end
