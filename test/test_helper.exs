run_integration =
  System.get_env("FALKORDB_RUN_INTEGRATION")
  |> to_string()
  |> String.downcase()
  |> Kernel.in(["1", "true", "yes", "on"])

run_sentinel_integration =
  System.get_env("FALKORDB_SENTINELS")
  |> FalkorDB.TestSupport.IntegrationHelpers.parse_sentinels()
  |> Kernel.!=([])

exclude_tags =
  cond do
    not run_integration ->
      [integration: true]

    run_sentinel_integration ->
      []

    true ->
      [sentinel: true]
  end

ExUnit.start(exclude: exclude_tags)
