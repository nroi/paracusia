defmodule Paracusia.PlayerState do
  defstruct current_song: nil,
            playlist: [],
            status: %Paracusia.PlayerState.Status{}
end
