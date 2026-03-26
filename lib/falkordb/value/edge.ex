defmodule FalkorDB.Value.Edge do
  @moduledoc """
  Compact edge value representation.
  """

  @type t :: %__MODULE__{
          id: integer(),
          relationship_type: String.t(),
          source_id: integer(),
          destination_id: integer(),
          properties: %{optional(String.t()) => term()}
        }

  defstruct [:id, :relationship_type, :source_id, :destination_id, properties: %{}]
end
