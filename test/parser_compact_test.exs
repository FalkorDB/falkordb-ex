defmodule FalkorDB.Parser.CompactTest do
  use ExUnit.Case, async: true

  alias FalkorDB.Parser.Compact
  alias FalkorDB.Value.Date
  alias FalkorDB.Value.DateTime
  alias FalkorDB.Value.Duration
  alias FalkorDB.Value.Edge
  alias FalkorDB.Value.Node
  alias FalkorDB.Value.Point
  alias FalkorDB.Value.Time

  test "parses complex compact reply including temporal values" do
    reply = [
      [
        [1, "n"],
        [1, "r"],
        [1, "point"],
        [1, "attrs"],
        [1, "dt"],
        [1, "date"],
        [1, "time"],
        [1, "duration"]
      ],
      [
        [
          [8, [1, [0], [[0, 2, "Alice"], [1, 3, 30]]]],
          [7, [2, 0, 1, 3, [[2, 3, 2020]]]],
          [11, ["40.7128", "-74.0060"]],
          [10, ["nickname", [2, "ali"], "verified", [4, "true"]]],
          [13, 1_704_067_200],
          [14, 1_704_067_200],
          [15, 3_661],
          [16, 42]
        ]
      ],
      [
        "Nodes created: 1",
        "Cached execution: true",
        "Query internal execution time: 1.23 milliseconds"
      ]
    ]

    resolvers = %{
      label: fn 0 -> "Person" end,
      relationship: fn 0 -> "KNOWS" end,
      property: fn
        0 -> "name"
        1 -> "age"
        2 -> "since"
      end
    }

    assert {:ok, result} = Compact.parse(reply, resolvers)
    assert result.headers == ["n", "r", "point", "attrs", "dt", "date", "time", "duration"]

    row = hd(result.data)
    assert %Node{} = row["n"]
    assert %Edge{} = row["r"]
    assert %Point{} = row["point"]
    assert %DateTime{} = row["dt"]
    assert %Date{} = row["date"]
    assert %Time{} = row["time"]
    assert %Duration{} = row["duration"]
    assert row["attrs"] == %{"nickname" => "ali", "verified" => true}

    assert result.stats["nodes_created"] == 1
    assert result.stats["cached_execution"] == true
    assert result.stats["query_internal_execution_time"] == 1.23
  end

  test "parses metadata only reply" do
    assert {:ok, result} = Compact.parse([["Cached execution: 1"]], %{})
    assert result.headers == nil
    assert result.data == nil
    assert result.stats["cached_execution"] == 1
  end

  test "parses typed double values represented as integer strings" do
    reply = [
      [[1, "score"]],
      [[[5, "2"]]],
      ["Cached execution: 0"]
    ]

    assert {:ok, result} = Compact.parse(reply, %{})
    assert [%{"score" => 2.0}] = result.data
  end
end
