defmodule FalkorDB.Connection do
  @moduledoc false

  @type mode :: :single | :sentinel

  @type t :: %__MODULE__{
          adapter: module(),
          pid: pid() | atom(),
          mode: mode()
        }

  defstruct [:adapter, :pid, :mode]

  @spec command(t(), [String.Chars.t()]) :: {:ok, term()} | {:error, term()}
  def command(%__MODULE__{adapter: adapter, pid: pid}, command) do
    adapter.command(pid, Enum.map(command, &to_string/1))
  end

  @spec pipeline(t(), [[String.Chars.t()]]) :: {:ok, [term()]} | {:error, term()}
  def pipeline(%__MODULE__{adapter: adapter, pid: pid}, pipeline) do
    normalized = Enum.map(pipeline, fn command -> Enum.map(command, &to_string/1) end)
    adapter.pipeline(pid, normalized)
  end

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{adapter: adapter, pid: pid}), do: adapter.stop(pid)

  @spec with(module(), pid() | atom(), mode()) :: t()
  def with(adapter, pid, mode) when is_atom(adapter),
    do: %__MODULE__{adapter: adapter, pid: pid, mode: mode}
end
