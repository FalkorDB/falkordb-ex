defmodule FalkorDB.Connection do
  @moduledoc false

  @type mode :: :single | :sentinel

  @type t :: %__MODULE__{
          adapter: module(),
          pid: pid() | atom(),
          mode: mode(),
          timeout: timeout()
        }

  # No client-side command deadline by default: graph queries routinely exceed
  # Redix's default 5000ms timeout (bulk loads, deep traversals), which would
  # otherwise fail the call with a connection error while the server keeps
  # executing the query - so retrying could duplicate writes. Query duration is
  # governed by the server's TIMEOUT / TIMEOUT_DEFAULT configuration instead,
  # matching the other FalkorDB clients. Opt into a deadline with the
  # `:command_timeout` connect option.
  @default_timeout :infinity

  defstruct [:adapter, :pid, :mode, timeout: @default_timeout]

  @spec command(t(), [String.Chars.t()]) :: {:ok, term()} | {:error, term()}
  def command(%__MODULE__{adapter: adapter, pid: pid, timeout: timeout}, command) do
    adapter.command(pid, Enum.map(command, &to_string/1), timeout)
  end

  @spec pipeline(t(), [[String.Chars.t()]]) :: {:ok, [term()]} | {:error, term()}
  def pipeline(%__MODULE__{adapter: adapter, pid: pid, timeout: timeout}, pipeline) do
    normalized = Enum.map(pipeline, fn command -> Enum.map(command, &to_string/1) end)
    adapter.pipeline(pid, normalized, timeout)
  end

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{adapter: adapter, pid: pid}), do: adapter.stop(pid)

  @spec with(module(), pid() | atom(), mode(), timeout()) :: t()
  def with(adapter, pid, mode, timeout \\ @default_timeout) when is_atom(adapter),
    do: %__MODULE__{adapter: adapter, pid: pid, mode: mode, timeout: timeout}

  @spec timeout_from_opts(keyword()) :: timeout()
  def timeout_from_opts(opts), do: Keyword.get(opts, :command_timeout, @default_timeout)
end
