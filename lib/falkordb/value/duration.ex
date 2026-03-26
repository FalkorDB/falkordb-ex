defmodule FalkorDB.Value.Duration do
  @moduledoc """
  Compact duration value representation.
  """

  @type t :: %__MODULE__{total_seconds: integer()}

  defstruct [:total_seconds]
end
