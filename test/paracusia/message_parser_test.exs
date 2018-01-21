defmodule Paracusia.MessageParserTest do
  use ExUnit.Case
  alias Paracusia.MessageParser
  doctest Paracusia.MessageParser

  test "parse_decoder_response" do
    mpd_response = ~s(plugin: mad
suffix: mp3
suffix: mp2
mime_type: audio/mpeg
plugin: vorbis
suffix: ogg
suffix: oga
mime_type: application/ogg
mime_type: application/x-ogg
mime_type: audio/ogg
mime_type: audio/vorbis
mime_type: audio/vorbis+ogg
mime_type: audio/x-ogg
mime_type: audio/x-vorbis
mime_type: audio/x-vorbis+ogg
plugin: oggflac
suffix: ogg
suffix: oga
mime_type: application/ogg
mime_type: application/x-ogg
mime_type: audio/ogg
mime_type: audio/x-flac+ogg
mime_type: audio/x-ogg)

    expect = %{
      "mad" => %{suffixes: ["mp3", "mp2"], mime_types: ["audio/mpeg"]},
      "vorbis" => %{
        suffixes: ["ogg", "oga"],
        mime_types: [
          "application/ogg",
          "application/x-ogg",
          "audio/ogg",
          "audio/vorbis",
          "audio/vorbis+ogg",
          "audio/x-ogg",
          "audio/x-vorbis",
          "audio/x-vorbis+ogg"
        ]
      },
      "oggflac" => %{
        suffixes: ["ogg", "oga"],
        mime_types: [
          "application/ogg",
          "application/x-ogg",
          "audio/ogg",
          "audio/x-flac+ogg",
          "audio/x-ogg"
        ]
      }
    }

    assert Paracusia.MessageParser.parse_decoder_response(mpd_response) == expect
  end

  test "split_first_delim/1 should return a non-empty list for non-empty strings" do
    s =
      "language: Elixir\nawesome: true\nwidely used: not yet\n" <>
        "language: JavaScript\nawesome: false\nwidely used: yes\n"

    result = MessageParser.split_first_delim(s)

    expected = [
      ["language: Elixir", "awesome: true", "widely used: not yet"],
      ["language: JavaScript", "awesome: false", "widely used: yes"]
    ]

    assert result == expected
  end

  test "split_first_delim/1 should return a empty list for the empty string" do
    assert MessageParser.split_first_delim("") == []
  end

  test "parse_outputs" do
    s =
      "outputid: 1\noutputenabled: 1\noutputname: pulse\n" <>
        "outputid: 2\noutputenabled: 0\noutputname: alsa\n"

    expected = [
      %Paracusia.MpdClient.AudioOutputs{outputid: 1, outputenabled: true, outputname: "pulse"},
      %Paracusia.MpdClient.AudioOutputs{outputid: 2, outputenabled: false, outputname: "alsa"}
    ]

    assert MessageParser.parse_outputs(s) == expected
  end

  test "parse_items" do
    s = ~s(file: fname\nkey1: value1\nkey2: value2\nplaylist: pname\nk1: v1\n)

    expected = [
      %{"file" => "fname", "key1" => "value1", "key2" => "value2"},
      %{"playlist" => "pname", "k1" => "v1"}
    ]

    assert MessageParser.parse_items(s) == expected
  end
end
