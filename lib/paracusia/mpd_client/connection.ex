defmodule Paracusia.MpdClient.Connection do
  @doc"""
  Kills MPD.
  """
  def kill() do
    GenServer.call(Paracusia.MpdClient, :kill)
  end
end
