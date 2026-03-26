defmodule FalkorDB.Value.Path do
  @moduledoc """
  Compact path value representation.
  """

  @type t :: %__MODULE__{
          nodes: [FalkorDB.Value.Node.t()],
          edges: [FalkorDB.Value.Edge.t()]
        }

  defstruct nodes: [], edges: []
end
