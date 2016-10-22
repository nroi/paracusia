defmodule Paracusia.MpdClient.ChannelsTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Channels

  setup_all do
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "subscribe, unsubscribe, send_message should return :ok" do
    :ok = Channels.subscribe("ratings")
    :ok = Channels.unsubscribe("ratings")
    :ok = Channels.send_message("ratings", "5")
  end

  test "messages should return a map containing messages" do
    {:ok, %{"ratings" => ["5"]}} = Channels.__messages__
  end

  test "all should return a list of available channels" do
    {:ok, ["ratings", "stuff"]} = Channels.all
  end

end
