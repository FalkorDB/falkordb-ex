defmodule FalkorDB.DispatchTest do
  use ExUnit.Case, async: true

  alias FalkorDB
  alias FalkorDB.TestSupport.FakeAdapter

  test "dispatches db-level commands including udf, debug, acl, and password" do
    responder = fn
      {:command, ["GRAPH.LIST"], _state} ->
        {:ok, ["a", "b"]}

      {:command, ["GRAPH.CONFIG", "GET", "RESULTSET_SIZE"], _state} ->
        {:ok, [["RESULTSET_SIZE", "100"]]}

      {:command, ["GRAPH.CONFIG", "SET", "RESULTSET_SIZE", "200"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.INFO"], _state} ->
        {:ok, ["# Running queries", []]}

      {:command, ["GRAPH.INFO", "RunningQueries"], _state} ->
        {:ok, ["# Running queries", []]}

      {:command, ["GRAPH.UDF", "LOAD", "REPLACE", "lib", "function f() {}"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.UDF", "LIST", "lib", "WITHCODE"], _state} ->
        {:ok, []}

      {:command, ["GRAPH.UDF", "DELETE", "lib"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.UDF", "FLUSH"], _state} ->
        {:ok, "OK"}

      {:command, ["GRAPH.DEBUG", "AUX", "START"], _state} ->
        {:ok, 1}

      {:command, ["GRAPH.ACL", "GETUSER", "alice"], _state} ->
        {:ok, %{}}

      {:command, ["GRAPH.PASSWORD", "ADD", "secret"], _state} ->
        {:ok, "OK"}

      {:command, command, _state} ->
        {:ok, command}
    end

    {:ok, pid} = FakeAdapter.start_link(responder: responder)
    db = FalkorDB.from_connection(FakeAdapter.connection(pid, :single))

    assert {:ok, ["a", "b"]} = FalkorDB.list(db)
    assert {:ok, _} = FalkorDB.config_get(db, "RESULTSET_SIZE")
    assert {:ok, "OK"} = FalkorDB.config_set(db, "RESULTSET_SIZE", 200)
    assert {:ok, _} = FalkorDB.info(db)
    assert {:ok, _} = FalkorDB.info(db, "RunningQueries")
    assert {:ok, "OK"} = FalkorDB.udf_load(db, "lib", "function f() {}", replace: true)
    assert {:ok, []} = FalkorDB.udf_list(db, "lib", with_code: true)
    assert {:ok, "OK"} = FalkorDB.udf_delete(db, "lib")
    assert {:ok, "OK"} = FalkorDB.udf_flush(db)
    assert {:ok, 1} = FalkorDB.debug(db, ["AUX", "START"])
    assert {:ok, %{}} = FalkorDB.acl(db, ["GETUSER", "alice"])
    assert {:ok, "OK"} = FalkorDB.set_password(db, :add, "secret")

    calls = FakeAdapter.command_calls(pid)
    assert ["GRAPH.LIST"] in calls
    assert ["GRAPH.UDF", "FLUSH"] in calls
    assert ["GRAPH.PASSWORD", "ADD", "secret"] in calls
  end
end
