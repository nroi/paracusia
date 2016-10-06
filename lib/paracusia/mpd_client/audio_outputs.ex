defmodule Paracusia.MpdClient.AudioOutputs do

  @doc"""
  Turns an output off.
  """
  @spec disable(integer) :: :ok | {:error, {String.t, String.t}}
  def disable(id) do
    GenServer.call(Paracusia.MpdClient, {:send_and_ack, "disableoutput #{id}\n"})
  end

  @doc"""
  Turns an output on.
  """
  @spec enable(integer) :: :ok | {:error, {String.t, String.t}}
  def enable(id) do
    GenServer.call(Paracusia.MpdClient, {:send_and_ack, "enableoutput #{id}\n"})
  end

  @doc"""
  Turns an output on or off, depending on the current state.
  """
  @spec toggle(integer) :: :ok | {:error, {String.t, String.t}}
  def toggle(id) do
    GenServer.call(Paracusia.MpdClient, {:send_and_ack, "toggleoutput #{id}\n"})
  end

  @doc"""
  Returns a map containing information about all audio outputs.
  """
  def list() do
    GenServer.call(Paracusia.MpdClient, :outputs)
  end

end