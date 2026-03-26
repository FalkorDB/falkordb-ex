defmodule FalkorDB.Value.DateTime do
  @moduledoc """
  Compact datetime value representation.
  """

  @type t :: %__MODULE__{
          unix_seconds: integer(),
          value: DateTime.t()
        }

  defstruct [:unix_seconds, :value]
end
