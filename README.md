# falkordb-ex
Elixir client for FalkorDB 4.16.x built on top of [Redix](https://github.com/whatyouhide/redix).
V1 supports single-node and sentinel topologies.
## Supported FalkorDB deployments
- Single-node / standalone FalkorDB (`mode: :single`) via URL or host/port.
- Sentinel-managed FalkorDB (`mode: :sentinel`) via sentinel endpoints and group name.
- Current V1 scope does not include Redis Cluster mode.
## Installation
Add `:falkordb` to your dependencies:
```elixir
def deps do
  [
    {:falkordb, "~> 0.1.0"}
  ]
end
```
## Quick start
```elixir
{:ok, db} =
  FalkorDB.connect(
    mode: :single,
    url: "redis://127.0.0.1:6379"
  )

graph = FalkorDB.select_graph(db, "social")

{:ok, _} = FalkorDB.Graph.query(graph, "CREATE (:Person {name: 'Alice'})")
{:ok, result} = FalkorDB.Graph.ro_query(graph, "MATCH (n:Person) RETURN n.name AS name")

IO.inspect(result.data)
:ok = FalkorDB.stop(db)
```
## Sentinel
```elixir
{:ok, db} =
  FalkorDB.connect(
    mode: :sentinel,
    group: "mymaster",
    sentinels: [{"127.0.0.1", 26_379}, {"127.0.0.1", 26_380}]
  )
```
## API coverage
The client includes wrappers for the FalkorDB 4.16.x module command surface:
- Query: `GRAPH.QUERY`, `GRAPH.RO_QUERY`, `GRAPH.EXPLAIN`, `GRAPH.PROFILE`
- Graph ops: `GRAPH.DELETE`, `GRAPH.COPY`, `GRAPH.RESTORE`, `GRAPH.EFFECT`, `GRAPH.BULK`
- Schema/admin: `GRAPH.CONSTRAINT`, `GRAPH.SLOWLOG`, `GRAPH.MEMORY`, `GRAPH.CONFIG`, `GRAPH.LIST`, `GRAPH.INFO`
- Advanced/admin: `GRAPH.DEBUG`, `GRAPH.ACL`, `GRAPH.PASSWORD`, `GRAPH.UDF`
Compact parsing includes graph entities and temporal types (`datetime`, `date`, `time`, `duration`).
## Test coverage
Test coverage includes both fast unit tests and opt-in integration tests:
- Unit tests cover command dispatch/building, query parameter serialization, compact parser behavior, and schema cache metadata resolution paths.
- Standalone integration tests cover end-to-end query flow (nodes/edges/paths), temporal values, UDF lifecycle, and indexing/search flows including vector, full-text, and geospatial queries.
- Sentinel integration tests cover connecting through sentinel and executing graph commands in sentinel mode.
## Quality checks
Run local checks:
```bash
mix check
```
`mix check` runs:
- `mix format --check-formatted`
- `mix credo --strict`
- `mix test`
## Integration tests
Integration tests are opt-in and disabled by default.
To run them:
```bash
FALKORDB_RUN_INTEGRATION=1 mix test
```
### Standalone
Environment:
- `FALKORDB_URL` (default: `redis://127.0.0.1:6379`)
- `FALKORDB_TEST_GRAPH` (default: `elixir-test`)
Coverage highlights:
- graph CRUD/query execution and compact parsing
- temporal values (`date`, `time`, `datetime`, `duration`)
- UDF load/list/query/delete/flush flows
- index creation and search (`VECTOR`, `FULLTEXT`, geospatial `RANGE`)
### Sentinel
Environment:
- `FALKORDB_SENTINELS` (comma-separated `host:port`, example: `127.0.0.1:26379,127.0.0.1:26380`)
- `FALKORDB_SENTINEL_GROUP` (default: `mymaster`)
Coverage highlights:
- sentinel discovery and connection
- query/list command flow against sentinel-managed deployment
## Examples
Runnable scripts are available under `examples/`:
- `examples/quickstart.exs`
- `examples/sentinel.exs`
## Release
This repo includes:
- CI workflow: `.github/workflows/ci.yml`
- Hex release workflow: `.github/workflows/release.yml`
Set `HEX_API_KEY` in repository secrets before publishing tags (for example `v0.1.0`).
