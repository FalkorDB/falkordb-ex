group = System.get_env("FALKORDB_SENTINEL_GROUP", "mymaster")

sentinels =
  System.get_env("FALKORDB_SENTINELS", "127.0.0.1:26379")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn endpoint ->
    case String.split(endpoint, ":", parts: 2) do
      [host, port] -> {host, String.to_integer(port)}
      [host] -> {host, 26_379}
    end
  end)

{:ok, db} = FalkorDB.connect(mode: :sentinel, sentinels: sentinels, group: group)
IO.inspect(FalkorDB.list(db), label: "Graphs")
:ok = FalkorDB.stop(db)
