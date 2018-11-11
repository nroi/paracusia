defmodule Paracusia.MpdClient.Database.FindExpression do
  @type t :: %Paracusia.MpdClient.Database.FindExpression{
          filters: [{MpdTypes.tag(), String.t()}],
          window: {integer, integer} | nil,
          order_by: binary,
          sort_direction: :asc | :desc | nil
        }
  defstruct filters: nil,
            window: nil,
            order_by: nil,
            sort_direction: :asc
end
