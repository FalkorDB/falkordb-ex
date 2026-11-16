defmodule FalkorDB.Connection.RedixSentinelTest do
  use ExUnit.Case, async: true

  alias FalkorDB.Connection.RedixSentinel
  alias FalkorDB.TestSupport.IntegrationHelpers

  test "normalizes host:port strings to keyword lists" do
    assert {:ok, [host: "127.0.0.1", port: 26_379]} =
             RedixSentinel.normalize_sentinel_address("127.0.0.1:26379")
  end

  test "normalizes bare host to default sentinel port" do
    assert {:ok, [host: "sentinel.local", port: 26_379]} =
             RedixSentinel.normalize_sentinel_address("sentinel.local")
  end

  test "keeps redis URIs unchanged" do
    assert {:ok, "redis://127.0.0.1:26379"} =
             RedixSentinel.normalize_sentinel_address("redis://127.0.0.1:26379")

    assert {:ok, "rediss://sentinel:26379"} =
             RedixSentinel.normalize_sentinel_address("rediss://sentinel:26379")
  end

  test "normalizes {host, port} tuples" do
    assert {:ok, [host: "127.0.0.1", port: 26_380]} =
             RedixSentinel.normalize_sentinel_address({"127.0.0.1", 26_380})
  end

  test "keeps keyword lists with host" do
    assert {:ok, [host: "s1", port: 26_379]} =
             RedixSentinel.normalize_sentinel_address(host: "s1", port: 26_379)
  end

  test "normalizes a mixed list of sentinel addresses" do
    assert {:ok, normalized} =
             RedixSentinel.normalize_sentinels([
               "127.0.0.1:26379",
               {"127.0.0.1", 26_380},
               "redis://127.0.0.1:26381"
             ])

    assert normalized == [
             [host: "127.0.0.1", port: 26_379],
             [host: "127.0.0.1", port: 26_380],
             "redis://127.0.0.1:26381"
           ]
  end

  test "rejects invalid sentinel addresses" do
    assert {:error, _} = RedixSentinel.normalize_sentinel_address("host:not-a-port")
    assert {:error, _} = RedixSentinel.normalize_sentinel_address({"host", 99_999})
    assert {:error, _} = RedixSentinel.normalize_sentinels(:not_a_list)
  end

  test "parse_sentinels returns redix-compatible values" do
    assert IntegrationHelpers.parse_sentinels("127.0.0.1:26379,redis://s2:26380") == [
             [host: "127.0.0.1", port: 26_379],
             "redis://s2:26380"
           ]
  end
end
