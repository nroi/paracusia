defmodule Paracusia.MessageParserTest do
  use ExUnit.Case
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
      "mad" =>
        %{suffixes: ["mp3", "mp2"],
          mime_types: ["audio/mpeg"]},
       "vorbis" =>
         %{suffixes: ["ogg", "oga"],
           mime_types: ["application/ogg",
                        "application/x-ogg",
                        "audio/ogg",
                        "audio/vorbis",
                        "audio/vorbis+ogg",
                        "audio/x-ogg",
                        "audio/x-vorbis",
                        "audio/x-vorbis+ogg"]},
       "oggflac" =>
         %{suffixes: ["ogg", "oga"],
           mime_types: ["application/ogg",
                        "application/x-ogg",
                        "audio/ogg",
                        "audio/x-flac+ogg",
                        "audio/x-ogg"]}}
    assert Paracusia.MessageParser.parse_decoder_response(mpd_response) == expect
  end

end
