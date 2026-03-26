defmodule FalkorDB.QueryParameterSerializerTest do
  use ExUnit.Case, async: true

  alias FalkorDB.QueryParameterSerializer

  test "serializes scalar values deterministically" do
    serialized =
      QueryParameterSerializer.serialize(%{
        "active" => true,
        "age" => 30,
        "name" => "Alice",
        "nickname" => nil
      })

    assert serialized == ~s(active=true age=30 name="Alice" nickname=null)
  end

  test "escapes strings and serializes nested values" do
    serialized =
      QueryParameterSerializer.serialize(%{
        "list" => [1, "two", true, nil],
        "object" => %{"meta" => %{"level" => 5}, "name" => "Neo"},
        "path" => ~s(C:\\Users\\Alice),
        "quote" => ~s(say "hello")
      })

    assert serialized ==
             ~s(list=[1,"two",true,null] object={meta:{level:5},name:"Neo"} path="C:\\\\Users\\\\Alice" quote="say \\"hello\\"")
  end
end
