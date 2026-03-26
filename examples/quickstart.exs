url = System.get_env("FALKORDB_URL", "redis://127.0.0.1:6379")
graph_name = System.get_env("FALKORDB_GRAPH", "social")

{:ok, db} = FalkorDB.connect(mode: :single, url: url)
graph = FalkorDB.select_graph(db, graph_name)

{:ok, _} = FalkorDB.Graph.query(graph, "CREATE (:Person {name: 'Alice'})")
{:ok, result} = FalkorDB.Graph.ro_query(graph, "MATCH (n:Person) RETURN n.name AS name ORDER BY name")

IO.inspect(result.data, label: "Query rows")

_ = FalkorDB.Graph.delete(graph)
:ok = FalkorDB.stop(db)
