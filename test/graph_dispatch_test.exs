defmodule FalkorDB.GraphDispatchTest do
  use ExUnit.Case, async: true

  alias FalkorDB
  alias FalkorDB.Graph
  alias FalkorDB.TestSupport.FakeAdapter
  alias FalkorDB.Value.Edge
  alias FalkorDB.Value.Node

  test "graph APIs build expected commands and metadata cache loads once" do
    responder = fn
      {:command, ["GRAPH.QUERY", "social", _query, "--compact"], _state} ->
        {:ok,
         [
           [[1, "n"], [1, "e"]],
           [
             [
               [8, [1, [0], [[0, 2, "Alice"]]]],
               [7, [2, 0, 1, 3, [[2, 3, 2020]]]]
             ]
           ],
           ["Cached execution: 1"]
         ]}

      {:command, ["GRAPH.RO_QUERY", "social", "CALL db.labels()", "--compact"], _state} ->
        {:ok, [[[1, "label"]], [[[2, "Person"]]], ["Cached execution: 1"]]}

      {:command, ["GRAPH.RO_QUERY", "social", "CALL db.relationshipTypes()", "--compact"], _state} ->
        {:ok, [[[1, "relationship"]], [[[2, "KNOWS"]]], ["Cached execution: 1"]]}

      {:command, ["GRAPH.RO_QUERY", "social", "CALL db.propertyKeys()", "--compact"], _state} ->
        {:ok,
         [
           [[1, "property"]],
           [[[2, "name"]], [[2, "age"]], [[2, "since"]]],
           ["Cached execution: 1"]
         ]}

      {:command, ["GRAPH.MEMORY", "USAGE", "social", "SAMPLES", "10"], _state} ->
        {:ok, %{"total_graph_sz_mb" => 1}}

      {:command, ["GRAPH.SLOWLOG", "social"], _state} ->
        {:ok, [[1_700_000_000, "GRAPH.QUERY", "MATCH (n) RETURN n", "1.23"]]}

      {:command, ["GRAPH.SLOWLOG", "social", "RESET"], _state} ->
        {:ok, "OK"}

      {:command,
       [
         "GRAPH.CONSTRAINT",
         "social",
         "CREATE",
         "UNIQUE",
         "NODE",
         "Person",
         "PROPERTIES",
         "1",
         "id"
       ], _state} ->
        {:ok, "PENDING"}

      {:command,
       [
         "GRAPH.CONSTRAINT",
         "social",
         "DROP",
         "UNIQUE",
         "NODE",
         "Person",
         "PROPERTIES",
         "1",
         "id"
       ], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.BULK", "social", "BEGIN", "1", "0", "(0,:Person{name:\"Alice\"})"],
       _state} ->
        {:ok, "1 nodes created, 0 edges created"}

      {:command, ["GRAPH.COPY", "social", "social_copy"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.RESTORE", "social", "payload"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.EFFECT", "social", "blob"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.DELETE", "social"], _state} ->
        {:ok, "OK"}

      {:command, command, _state} ->
        {:ok, command}
    end

    {:ok, pid} = FakeAdapter.start_link(responder: responder)
    db = FalkorDB.from_connection(FakeAdapter.connection(pid, :single))
    graph = FalkorDB.select_graph(db, "social")

    assert {:ok, first} = Graph.query(graph, "MATCH (n)-[e]->() RETURN n,e")
    assert %Node{} = first.data |> hd() |> Map.fetch!("n")
    assert %Edge{} = first.data |> hd() |> Map.fetch!("e")

    assert {:ok, second} = Graph.query(graph, "MATCH (n)-[e]->() RETURN n,e")
    assert %Node{} = second.data |> hd() |> Map.fetch!("n")

    assert {:ok, %{"total_graph_sz_mb" => 1}} = Graph.memory_usage(graph, 10)
    assert {:ok, [%{command: "GRAPH.QUERY"}]} = Graph.slowlog(graph)
    assert {:ok, "OK"} = Graph.slowlog_reset(graph)
    assert {:ok, "PENDING"} = Graph.constraint_create(graph, :unique, :node, "Person", ["id"])
    assert {:ok, "OK"} = Graph.constraint_drop(graph, :unique, :node, "Person", ["id"])

    assert {:ok, "1 nodes created, 0 edges created"} =
             Graph.bulk_insert(graph,
               begin: true,
               node_count: 1,
               edge_count: 0,
               entries: ["(0,:Person{name:\"Alice\"})"]
             )

    assert {:ok, "OK"} = Graph.copy(graph, "social_copy")
    assert {:ok, "OK"} = Graph.restore(graph, "payload")
    assert {:ok, "OK"} = Graph.effect(graph, "blob")
    assert {:ok, "OK"} = Graph.delete(graph)

    metadata_calls =
      FakeAdapter.command_calls(pid)
      |> Enum.filter(fn
        ["GRAPH.RO_QUERY", "social", "CALL db.labels()", "--compact"] -> true
        ["GRAPH.RO_QUERY", "social", "CALL db.relationshipTypes()", "--compact"] -> true
        ["GRAPH.RO_QUERY", "social", "CALL db.propertyKeys()", "--compact"] -> true
        _ -> false
      end)

    assert length(metadata_calls) == 3
  end
end
