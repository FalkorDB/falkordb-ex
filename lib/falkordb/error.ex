defmodule FalkorDB.Error do
  @moduledoc """
  Base FalkorDB exception.
  """

  defexception [:message, :reason]
end

defmodule FalkorDB.ConnectionError do
  @moduledoc """
  Raised/returned when connectivity operations fail.
  """

  defexception [:message, :reason]
end

defmodule FalkorDB.CommandError do
  @moduledoc """
  Raised/returned when Redis/FalkorDB command execution fails.
  """

  defexception [:message, :reason]
end

defmodule FalkorDB.ParseError do
  @moduledoc """
  Raised/returned when compact result parsing fails.
  """

  defexception [:message, :reason]
end
