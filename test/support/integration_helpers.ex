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

  @spec parse_sentinels(String.t() | nil) :: [{String.t(), non_neg_integer()}]
  def parse_sentinels(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn endpoint ->
      case String.split(endpoint, ":", parts: 2) do
        [host, port] -> {host, String.to_integer(port)}
        [host] -> {host, 26_379}
      end
    end)
  end

  def parse_sentinels(_), do: []
end
