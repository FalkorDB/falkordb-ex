group = System.get_env("FALKORDB_SENTINEL_GROUP", "mymaster")

# host:port strings, {host, port} tuples, keyword lists, and redis:// URIs are all accepted.
sentinels =
  System.get_env("FALKORDB_SENTINELS", "127.0.0.1:26379")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

{:ok, db} = FalkorDB.connect(mode: :sentinel, sentinels: sentinels, group: group)
IO.inspect(FalkorDB.list(db), label: "Graphs")
:ok = FalkorDB.stop(db)
