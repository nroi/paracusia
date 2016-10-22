defmodule Paracusia.MpdClient.StickersTest do
  use ExUnit.Case
  alias Paracusia.MpdClient.Stickers
  @uri "flac/rammstein_-_mutter_\(2001\)/03._rammstein__sonne.flac"

  setup_all do
    Paracusia.Mock.start()
    :ok = Application.start(:paracusia)
    on_exit(fn ->
      :ok = Application.stop(:paracusia)
    end)
  end

  test "set,delete should return :ok" do
    :ok = Stickers.set(@uri, "rating", "5")
    :ok = Stickers.delete(@uri, "rating")
    :ok = Stickers.delete(@uri)
  end

  test "all should return a map" do
    {:ok, %{"playcount" => "3", "rating" => "1"}} = Stickers.all(@uri)
  end

  test "get should return the sticker value for the URI" do
    {:ok, "1"} = Stickers.get(@uri, "rating")
  end

  test "find should return a list of tuples" do
    {:ok, result} = Stickers.find("flac", "rating")
    expected = [
      {"flac/band_of_skulls_-_by_default/01_-_black_magic.flac", "5"},
      {"flac/rammstein_-_mutter_(2001)/02._rammstein__links_2_3_4.flac", "1"},
      {"flac/rammstein_-_mutter_(2001)/03._rammstein__sonne.flac", "1"}
    ]
    assert result == expected
  end


end
