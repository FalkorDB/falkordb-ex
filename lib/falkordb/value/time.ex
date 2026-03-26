defmodule FalkorDB.Value.Time do
  @moduledoc """
  Compact time value representation.
  """

  @type t :: %__MODULE__{
          unix_seconds: integer(),
          value: Time.t()
        }

  defstruct [:unix_seconds, :value]
end
