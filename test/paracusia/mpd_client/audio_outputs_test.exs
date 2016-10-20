defmodule Paracusia.MpdClient.AudioOutputsTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.AudioOutputs

  setup_all do
    Application.stop(:paracusia)
    port = Application.get_env(:paracusia, :test_port)
    System.put_env("MPD_HOST", "localhost")
    System.put_env("MPD_PORT", "#{port}")
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "all should return a list of all audio outputs" do
    {:ok, result} = AudioOutputs.all
    expected = [%Paracusia.MpdClient.AudioOutputs{outputenabled: true,
                                                  outputid: 0,
                                                  outputname: "pulse audio"}]
    assert result == expected
  end

  test "{enable,disable,toggle}output should return :ok" do
    :ok = AudioOutputs.enable(0)
    :ok = AudioOutputs.disable(0)
    :ok = AudioOutputs.toggle(0)
  end


end
