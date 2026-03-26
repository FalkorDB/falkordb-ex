defmodule FalkorDB.CommandBuilderTest do
  use ExUnit.Case, async: true

  alias FalkorDB.CommandBuilder

  test "builds query args with params timeout and compact" do
    args =
      CommandBuilder.query_arguments(
        "MATCH (n) RETURN n",
        %{params: %{"name" => "Alice"}, timeout: 5000}
      )

    assert args == ["CYPHER name=\"Alice\" MATCH (n) RETURN n", "TIMEOUT", "5000", "--compact"]
  end

  test "builds query args in timeout shorthand mode" do
    assert CommandBuilder.query_arguments("RETURN 1", 1500, false) == [
             "RETURN 1",
             "TIMEOUT",
             "1500"
           ]
  end

  test "builds strict memory usage syntax" do
    assert CommandBuilder.memory_usage_arguments("social", 10) == [
             "USAGE",
             "social",
             "SAMPLES",
             "10"
           ]
  end

  test "builds constraint args with property count" do
    args =
      CommandBuilder.constraint_arguments("CREATE", "UNIQUE", "NODE", "Person", [
        "email",
        "username"
      ])

    assert args == ["CREATE", "UNIQUE", "NODE", "Person", "PROPERTIES", "2", "email", "username"]
  end

  test "builds udf options" do
    assert CommandBuilder.udf_load_arguments("libA", "function f() {}", true) ==
             ["LOAD", "REPLACE", "libA", "function f() {}"]

    assert CommandBuilder.udf_list_arguments("libA", true) == ["LIST", "libA", "WITHCODE"]
  end
end
