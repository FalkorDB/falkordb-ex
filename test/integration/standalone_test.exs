defmodule FalkorDB.Integration.StandaloneTest do
  use ExUnit.Case, async: false

  alias FalkorDB
  alias FalkorDB.Graph
  alias FalkorDB.TestSupport.IntegrationHelpers
  alias FalkorDB.Value.Date, as: DateValue
  alias FalkorDB.Value.DateTime, as: DateTimeValue
  alias FalkorDB.Value.Duration
  alias FalkorDB.Value.Edge
  alias FalkorDB.Value.Node
  alias FalkorDB.Value.Path
  alias FalkorDB.Value.Point
  alias FalkorDB.Value.Time, as: TimeValue

  @moduletag :integration

  setup_all do
    if IntegrationHelpers.integration_enabled?() do
      :ok
    else
      {:ok, skip: "set FALKORDB_RUN_INTEGRATION=1 to run integration tests"}
    end
  end

  test "validates standalone functional flow including edges, UDF, and temporal values" do
    url = System.get_env("FALKORDB_URL", "redis://127.0.0.1:6379")
    graph_name = IntegrationHelpers.test_graph_name()
    udf_library = "elixir_udf_lib"

    {:ok, db} = FalkorDB.connect(mode: :single, url: url)
    graph = FalkorDB.select_graph(db, graph_name)

    on_exit(fn ->
      cleanup(graph, db)
    end)

    _ = FalkorDB.udf_flush(db)

    _ = Graph.delete(graph)

    assert {:ok, create_result} =
             Graph.query(
               graph,
               "CREATE (a:Person {name: \"Alice\"})-[r:KNOWS {since: 2024}]->(b:Person {name: \"Bob\"}) RETURN a, r, b"
             )

    assert create_result.stats["nodes_created"] == 2
    assert create_result.stats["relationships_created"] == 1

    create_row = hd(create_result.data)
    assert %Node{} = create_row["a"]
    assert %Edge{} = create_row["r"]
    assert %Node{} = create_row["b"]
    assert create_row["a"].properties["name"] == "Alice"
    assert create_row["r"].relationship_type == "KNOWS"
    assert create_row["r"].properties["since"] == 2024
    assert create_row["b"].properties["name"] == "Bob"

    assert {:ok, count_result} =
             Graph.ro_query(
               graph,
               "MATCH (a:Person)-[r:KNOWS]->(b:Person) RETURN count(a) AS a_count, count(r) AS r_count, count(b) AS b_count"
             )

    count_row = hd(count_result.data)
    assert count_row["a_count"] == 1
    assert count_row["r_count"] == 1
    assert count_row["b_count"] == 1

    assert {:ok, path_result} =
             Graph.ro_query(graph, "MATCH p=(a:Person)-[:KNOWS]->(b:Person) RETURN p")

    assert %Path{} = path_result.data |> hd() |> Map.fetch!("p")

    assert {:ok, temporal_result} =
             Graph.ro_query(
               graph,
               "RETURN date({year: 2024, month: 1, day: 2}) AS d, localtime({hour: 3, minute: 4, second: 5}) AS lt, localdatetime({year: 2024, month: 1, day: 2, hour: 3, minute: 4, second: 5}) AS ldt, duration({seconds: 42}) AS dur"
             )

    temporal_row = hd(temporal_result.data)
    assert %DateValue{value: ~D[2024-01-02]} = temporal_row["d"]
    assert %TimeValue{value: ~T[03:04:05]} = temporal_row["lt"]
    assert %DateTimeValue{value: ~U[2024-01-02 03:04:05Z]} = temporal_row["ldt"]
    assert %Duration{total_seconds: 42} = temporal_row["dur"]

    udf_script = """
    function Add(a, b) { return a + b; }
    function Greeting(name) { return "hello " + name; }
    falkor.register("Add", Add);
    falkor.register("Greeting", Greeting);
    """

    assert {:ok, "OK"} = FalkorDB.udf_load(db, udf_library, udf_script, replace: true)
    assert {:ok, udf_list_reply} = FalkorDB.udf_list(db, udf_library, with_code: true)

    [library_entry] = udf_list_reply
    library_info = library_entry_to_map(library_entry)

    assert library_info["library_name"] == udf_library
    assert "Add" in (library_info["functions"] || [])
    assert "Greeting" in (library_info["functions"] || [])
    assert String.contains?(library_info["library_code"] || "", "falkor.register(\"Add\", Add);")

    assert {:ok, udf_query_result} =
             Graph.ro_query(
               graph,
               "RETURN elixir_udf_lib.Add(2, 3) AS sum, elixir_udf_lib.Greeting(\"Alice\") AS greeting"
             )

    udf_row = hd(udf_query_result.data)
    assert udf_row["sum"] == 5
    assert udf_row["greeting"] == "hello Alice"

    assert {:ok, "OK"} = FalkorDB.udf_delete(db, udf_library)
    assert {:ok, []} = FalkorDB.udf_list(db, udf_library, with_code: false)
  end

  test "validates advanced indexing flows for vector, full-text, and geospatial search" do
    url = System.get_env("FALKORDB_URL", "redis://127.0.0.1:6379")
    graph_name = "#{IntegrationHelpers.test_graph_name()}-advanced-indexes"

    {:ok, db} = FalkorDB.connect(mode: :single, url: url)
    graph = FalkorDB.select_graph(db, graph_name)

    on_exit(fn ->
      cleanup(graph, db)
    end)

    _ = Graph.delete(graph)

    assert {:ok, _} =
             Graph.query(
               graph,
               """
               CREATE
                 (:Doc {id: "doc-1", title: "Graph Traversals", body: "Connected paths and traversals", embedding: vecf32([1.0, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])}),
                 (:Doc {id: "doc-2", title: "Vector Similarity", body: "Cosine search over embeddings", embedding: vecf32([0.0, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0])}),
                 (:Doc {id: "doc-3", title: "Geo Search", body: "Distance queries over locations", embedding: vecf32([0.0, 0.0, 1.0, 0.1, 0.0, 0.0, 0.0, 0.0])}),
                 (:Place {name: "Tel Aviv", location: point({latitude: 32.0853, longitude: 34.7818})}),
                 (:Place {name: "Ramat Gan", location: point({latitude: 32.0684, longitude: 34.8248})}),
                 (:Place {name: "Jerusalem", location: point({latitude: 31.7683, longitude: 35.2137})})
               """
             )

    assert {:ok, _} =
             Graph.query(
               graph,
               "CREATE VECTOR INDEX FOR (d:Doc) ON (d.embedding) OPTIONS {dimension: 8, similarityFunction: 'cosine'}"
             )

    assert {:ok, _} =
             Graph.query(
               graph,
               "CALL db.idx.fulltext.createNodeIndex('Doc', 'title', 'body')"
             )

    assert {:ok, _} = Graph.query(graph, "CREATE INDEX FOR (p:Place) ON (p.location)")

    assert {:ok, indexes_result} =
             Graph.ro_query(
               graph,
               "CALL db.indexes() YIELD label, properties, types RETURN label, properties, types"
             )

    assert has_index?(indexes_result.data, "Doc", "embedding", "VECTOR")
    assert has_index?(indexes_result.data, "Doc", "title", "FULLTEXT")
    assert has_index?(indexes_result.data, "Doc", "body", "FULLTEXT")
    assert has_index?(indexes_result.data, "Place", "location", "RANGE")

    assert {:ok, vector_result} =
             Graph.ro_query(
               graph,
               "CALL db.idx.vector.queryNodes('Doc', 'embedding', 1, vecf32([0.95, 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])) YIELD node, score RETURN node.id AS id, score"
             )

    vector_row = hd(vector_result.data)
    assert vector_row["id"] == "doc-1"
    assert is_number(vector_row["score"])

    assert {:ok, fulltext_result} =
             Graph.ro_query(
               graph,
               "CALL db.idx.fulltext.queryNodes('Doc', 'cosine') YIELD node, score RETURN node.id AS id, score ORDER BY score DESC"
             )

    fulltext_ids = Enum.map(fulltext_result.data, &Map.get(&1, "id"))
    assert "doc-2" in fulltext_ids
    assert fulltext_ids != []
    Enum.each(fulltext_result.data, &assert(is_number(&1["score"])))

    assert {:ok, geo_result} =
             Graph.ro_query(
               graph,
               """
               WITH point({latitude: 32.0853, longitude: 34.7818}) AS center
               MATCH (p:Place)
               WHERE distance(p.location, center) <= 6000
               RETURN p.name AS name, p.location AS location
               ORDER BY name
               """
             )

    geo_names = Enum.map(geo_result.data, &Map.get(&1, "name"))
    assert "Tel Aviv" in geo_names
    assert "Ramat Gan" in geo_names
    refute "Jerusalem" in geo_names

    Enum.each(geo_result.data, fn row ->
      assert %Point{} = row["location"]
    end)
  end

  defp cleanup(graph, db) do
    _ = safe_execute(fn -> Graph.delete(graph) end)
    _ = safe_execute(fn -> FalkorDB.udf_flush(db) end)
    _ = safe_execute(fn -> FalkorDB.stop(db) end)
  end

  defp safe_execute(fun) when is_function(fun, 0) do
    fun.()
  catch
    :exit, _ -> :ok
  end

  defp library_entry_to_map(entry) when is_list(entry) do
    entry
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn
      [key, value], acc -> Map.put(acc, to_string(key), value)
      _partial, acc -> acc
    end)
  end

  defp has_index?(rows, label, property, type) when is_list(rows) do
    Enum.any?(rows, fn row ->
      row_label = row |> Map.get("label", "") |> to_string()
      row_properties = row |> Map.get("properties") |> normalize_properties()
      {property_keys, row_types} = row |> Map.get("types") |> normalize_types(property)

      row_label == label and (property in row_properties or property in property_keys) and
        Enum.any?(row_types, &(String.upcase(&1) == type))
    end)
  end

  defp normalize_properties(%{} = properties_map),
    do: properties_map |> Map.keys() |> Enum.map(&to_string/1)

  defp normalize_properties(value), do: normalize_string_list(value)

  defp normalize_types(%{} = types_map, property) do
    property_keys = types_map |> Map.keys() |> Enum.map(&to_string/1)

    type_values =
      Enum.flat_map(types_map, fn {key, values} ->
        if to_string(key) == property do
          normalize_string_list(values)
        else
          []
        end
      end)

    {property_keys, type_values}
  end

  defp normalize_types(value, _property), do: {[], normalize_string_list(value)}

  defp normalize_string_list(value) when is_list(value), do: Enum.map(value, &to_string/1)
  defp normalize_string_list(%{} = value), do: [inspect(value)]
  defp normalize_string_list(nil), do: []
  defp normalize_string_list(value), do: [to_string(value)]
end
