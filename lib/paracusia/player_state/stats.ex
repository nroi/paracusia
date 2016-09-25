defmodule Paracusia.PlayerState.Stats do
  defstruct artists: nil,      # number of artists
            albums: nil,       # number of albums
            songs: nil,        # number of songs
            uptime: nil,       # daemon uptime in seconds
            db_playtime: nil,  # sum of all song times in the db
            db_update: nil,    # last db update in UNIX time
            playtime: nil      # time length of music played
end
