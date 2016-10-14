defmodule Paracusia.MpdClient.Reflection do
  alias Paracusia.MpdClient
  alias Paracusia.MpdTypes
  alias Paracusia.MessageParser

  @moduledoc"""
  Provides information about MPD's configuration, available permissions etc.

  See also: https://musicpd.org/doc/protocol/reflection_commands.html
  """



  @doc"""
  Returns a list of commands the current user has access to.
  """
  @spec permitted_commands() :: {:ok, [String.t]} | MpdTypes.mpd_error
  def permitted_commands() do
    with {:ok, reply} <- MpdClient.send_and_recv("commands\n") do
      {:ok, reply |> Paracusia.MessageParser.parse_newline_separated_enum}
    end
  end


  @doc"""
  Returns a list of commands the current user does not have access to.
  """
  @spec forbidden_commands() :: {:ok, [String.t]} | MpdTypes.mpd_error
  def forbidden_commands() do
    with {:ok, reply} <- MpdClient.send_and_recv("notcommands\n") do
      {:ok, reply |> Paracusia.MessageParser.parse_newline_separated_enum}
    end
  end


  @doc"""
  Returns a list of available song metadata.
  """
  @spec tag_types() :: {:ok, [String.t]} | MpdTypes.mpd_error
  def tag_types() do
    with {:ok, reply} <- MpdClient.send_and_recv("tagtypes\n") do
      {:ok, reply |> Paracusia.MessageParser.parse_newline_separated_enum}
    end
  end


  @doc"""
  Returns a list of available URL handlers.
  """
  @spec url_handlers() :: {:ok, [String.t]} | MpdTypes.mpd_error
  def url_handlers() do
    with {:ok, reply} <- MpdClient.send_and_recv("urlhandlers\n") do
      {:ok, reply |> Paracusia.MessageParser.parse_newline_separated_enum}
    end
  end


  @doc"""
  Returns a mapping between decoder plugins and their supported suffixes and MIME types.

  ## Example response

      {:ok, %{
        "dsf" => %{mime_types: ["application/x-dsf"], suffixes: ["dsf"]},
        "ffmpeg" => %{mime_types: ["application/flv", "application/m4a", ...]
                      suffixes: ["16sv", "3g2", "3gp", "4xm", "8svx", "aa3", "aac", ...]},
        "flac" => %{mime_types: ["application/flac", "application/x-flac", ...],
                    suffixes: ["flac"]},
        ... }
      }
  """
  @spec decoders() :: {:ok, map} | MpdTypes.mpd_error
  def decoders() do
    with {:ok, reply} <- MpdClient.send_and_recv("decoders\n") do
      {:ok, reply |> MessageParser.parse_decoder_response}
    end
  end
end
