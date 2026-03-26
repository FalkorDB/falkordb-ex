defmodule FalkorDB.Value.Point do
  @moduledoc """
  Compact point value representation.
  """

  @type t :: %__MODULE__{
          latitude: float(),
          longitude: float()
        }

  defstruct [:latitude, :longitude]
end
