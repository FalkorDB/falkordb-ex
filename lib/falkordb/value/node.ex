defmodule FalkorDB.Value.Node do
  @moduledoc """
  Compact node value representation.
  """

  @type t :: %__MODULE__{
          id: integer(),
          labels: [String.t()],
          properties: %{optional(String.t()) => term()}
        }

  defstruct [:id, labels: [], properties: %{}]
end
