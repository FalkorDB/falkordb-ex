defmodule FalkorDB.Connection.Adapter do
  @moduledoc false

  @type redis_command :: [String.Chars.t()]
  @type redis_pipeline :: [redis_command()]

  @callback connect(keyword()) :: {:ok, FalkorDB.Connection.t()} | {:error, term()}
  @callback command(pid() | atom(), redis_command()) :: {:ok, term()} | {:error, term()}
  @callback pipeline(pid() | atom(), redis_pipeline()) :: {:ok, [term()]} | {:error, term()}
  @callback stop(pid() | atom()) :: :ok
end
