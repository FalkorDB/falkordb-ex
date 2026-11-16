defmodule FalkorDB.TestSupport.IntegrationHelpers do
  @moduledoc false
  @default_test_graph "elixir-test"

  @spec integration_enabled?() :: boolean()
  def integration_enabled? do
    System.get_env("FALKORDB_RUN_INTEGRATION")
    |> to_string()
    |> String.downcase()
    |> Kernel.in(["1", "true", "yes", "on"])
  end

  @spec test_graph_name() :: String.t()
  def test_graph_name do
    System.get_env("FALKORDB_TEST_GRAPH", @default_test_graph)
  end

  @doc """
  Parses `FALKORDB_SENTINELS` into Redix-compatible addresses.

  Accepts comma-separated `host:port`, bare `host` (port defaults to 26379), or full
  `redis://` / `rediss://` URIs. Returns keyword lists / URI strings that Redix accepts.
  """
  @spec parse_sentinels(String.t() | nil) :: [String.t() | keyword()]
  def parse_sentinels(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn endpoint ->
      case FalkorDB.Connection.RedixSentinel.normalize_sentinel_address(endpoint) do
        {:ok, normalized} ->
          normalized

        {:error, reason} ->
          raise ArgumentError,
                "invalid sentinel endpoint #{inspect(endpoint)}: #{inspect(reason)}"
      end
    end)
  end

  def parse_sentinels(_), do: []
end
