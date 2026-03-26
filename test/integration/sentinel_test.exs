defmodule FalkorDB.Integration.SentinelTest do
  use ExUnit.Case, async: false

  alias FalkorDB
  alias FalkorDB.Graph
  alias FalkorDB.TestSupport.IntegrationHelpers

  @moduletag :integration
  @moduletag :sentinel

  test "connects through sentinel and runs graph commands" do
    sentinels =
      System.get_env("FALKORDB_SENTINELS")
      |> IntegrationHelpers.parse_sentinels()

    group = System.get_env("FALKORDB_SENTINEL_GROUP", "mymaster")
    graph_name = IntegrationHelpers.test_graph_name()

    {:ok, db} = FalkorDB.connect(mode: :sentinel, sentinels: sentinels, group: group)
    graph = FalkorDB.select_graph(db, graph_name)

    on_exit(fn ->
      cleanup(graph, db)
    end)

    assert {:ok, _} = Graph.query(graph, "RETURN 1 AS ok")
    assert {:ok, graphs} = FalkorDB.list(db)
    assert is_list(graphs)
  end

  defp cleanup(graph, db) do
    _ =
      try do
        Graph.delete(graph)
      catch
        :exit, _ -> :ok
      end

    _ =
      try do
        FalkorDB.stop(db)
      catch
        :exit, _ -> :ok
      end
  end
end
