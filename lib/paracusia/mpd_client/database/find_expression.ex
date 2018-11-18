defmodule Paracusia.MpdClient.Database.FindExpression do
  alias Paracusia.MpdTypes

  @typedoc """
  A `FindExpression` describes what results to return, and how to return them.
  """
  @type t :: %Paracusia.MpdClient.Database.FindExpression{
          filters: [{MpdTypes.tag(), String.t()}],
          window: {integer, integer} | nil,
          order_by: MpdTypes.tag(),
          sort_direction: :asc | :desc | nil
        }
  defstruct filters: nil,
            window: nil,
            order_by: nil,
            sort_direction: :asc
end
