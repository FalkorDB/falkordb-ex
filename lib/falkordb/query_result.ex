defmodule FalkorDB.QueryResult do
  @moduledoc """
  Parsed query result for `GRAPH.QUERY` and `GRAPH.RO_QUERY` compact replies.
  """

  @type row :: %{optional(String.t()) => term()}

  @type t :: %__MODULE__{
          headers: [String.t()] | nil,
          data: [row()] | nil,
          stats: %{optional(String.t()) => term()},
          metadata: [String.t()]
        }

  defstruct headers: nil, data: nil, stats: %{}, metadata: []
end
