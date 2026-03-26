defmodule FalkorDB.Value.Date do
  @moduledoc """
  Compact date value representation.
  """

  @type t :: %__MODULE__{
          unix_seconds: integer(),
          value: Date.t()
        }

  defstruct [:unix_seconds, :value]
end
