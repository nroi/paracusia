defmodule Paracusia.MpdClient.Channels do
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes
  alias Paracusia.MessageParser

  @moduledoc """
  Functions for client to client communication over channels.

  See also: https://musicpd.org/doc/protocol/client_to_client.html
  """

  @doc """
  Subscribe to the channel and create it, if it does not already exist.

  `channel` is a name consisting of alphanumeric ASCII characters plus underscore, dash, dot and
  colon.
  """
  def subscribe(channel) do
    MpdClient.send_and_ack(~s(subscribe "#{channel}"\n))
  end

  @doc """
  Unsubscribe from channel.
  """
  def unsubscribe(channel) do
    MpdClient.send_and_ack(~s(unsubscribe "#{channel}"\n))
  end

  @doc """
  Returns a list of all available channels.
  """
  @spec all() :: {:ok, [String.t()]} | MpdTypes.mpd_error()
  def all() do
    with {:ok, reply} <- MpdClient.send_and_recv("channels\n") do
      result =
        reply
        |> String.split("\n", trim: true)
        |> Enum.map(fn "channel: " <> rest -> rest |> String.replace_suffix("\n", "") end)

      {:ok, result}
    end
  end

  # Returns a list of messages for each subscribed channel where new messages have arrived.
  #  Example response
  #    %{"ratings" => ["3", "4", "5"], "comments" => ["nice song", "depressing"]}
  @spec __messages__() :: {:ok, %{String.t() => [String.t()]}} | MpdTypes.mpd_error()
  def __messages__() do
    with {:ok, reply} <- MpdClient.send_and_recv("readmessages\n") do
      result =
        reply
        |> MessageParser.split_first_delim()
        |> Enum.map(fn ["channel: " <> channel, "message: " <> message] ->
          {channel, message}
        end)
        |> MessageParser.to_list_map()

      {:ok, result}
    end
  end

  @doc """
  Sends a message to the given channel.
  """
  @spec send_message(String.t(), String.t()) :: :ok | MpdTypes.mpd_error()
  def send_message(channel, message) do
    MpdClient.send_and_ack(~s(sendmessage "#{channel}" "#{message}"\n))
  end
end
