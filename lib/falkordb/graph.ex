defmodule FalkorDB.Graph do
  @moduledoc """
  Graph-scoped FalkorDB API.
  """

  alias FalkorDB.CommandBuilder
  alias FalkorDB.Parser.Compact
  alias FalkorDB.QueryResult
  alias FalkorDB.SchemaCache

  @type t :: %__MODULE__{
          db: FalkorDB.t(),
          name: String.t(),
          schema_cache: SchemaCache.t()
        }

  defstruct [:db, :name, :schema_cache]

  @spec new(FalkorDB.t(), String.t()) :: t()
  def new(db, name) when is_binary(name),
    do: %__MODULE__{db: db, name: name, schema_cache: SchemaCache.new()}

  def new(db, name), do: new(db, to_string(name))

  @spec query(t(), String.t(), keyword() | map() | integer() | nil) ::
          {:ok, QueryResult.t()} | {:error, term()}
  def query(%__MODULE__{} = graph, query, options \\ nil) do
    args = CommandBuilder.query_arguments(query, options, true)
    execute_query(graph, "GRAPH.QUERY", args)
  end

  @spec ro_query(t(), String.t(), keyword() | map() | integer() | nil) ::
          {:ok, QueryResult.t()} | {:error, term()}
  def ro_query(%__MODULE__{} = graph, query, options \\ nil) do
    args = CommandBuilder.query_arguments(query, options, true)
    execute_query(graph, "GRAPH.RO_QUERY", args)
  end

  @spec explain(t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def explain(%__MODULE__{} = graph, query) when is_binary(query) do
    with {:ok, reply} <- graph_command(graph, "GRAPH.EXPLAIN", [query]) do
      {:ok, normalize_lines(reply)}
    end
  end

  @spec profile(t(), String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def profile(%__MODULE__{} = graph, query) when is_binary(query) do
    with {:ok, reply} <- graph_command(graph, "GRAPH.PROFILE", [query]) do
      {:ok, normalize_lines(reply)}
    end
  end

  @spec delete(t()) :: {:ok, term()} | {:error, term()}
  def delete(%__MODULE__{} = graph) do
    result = graph_command(graph, "GRAPH.DELETE")
    SchemaCache.clear(graph.schema_cache)
    result
  end

  @spec copy(t(), String.t()) :: {:ok, term()} | {:error, term()}
  def copy(%__MODULE__{} = graph, destination_graph) when is_binary(destination_graph) do
    graph_command(graph, "GRAPH.COPY", [destination_graph])
  end

  @spec restore(t(), binary()) :: {:ok, term()} | {:error, term()}
  def restore(%__MODULE__{} = graph, payload) when is_binary(payload) do
    graph_command(graph, "GRAPH.RESTORE", [payload])
  end

  @spec effect(t(), binary()) :: {:ok, term()} | {:error, term()}
  def effect(%__MODULE__{} = graph, effects_payload) when is_binary(effects_payload) do
    graph_command(graph, "GRAPH.EFFECT", [effects_payload])
  end

  @spec bulk_insert(t(), keyword()) :: {:ok, term()} | {:error, term()}
  def bulk_insert(%__MODULE__{} = graph, options) when is_list(options) do
    begin? = Keyword.get(options, :begin, false)
    node_count = Keyword.fetch!(options, :node_count)
    edge_count = Keyword.fetch!(options, :edge_count)
    entries = Keyword.get(options, :entries, [])

    args =
      if(begin?, do: ["BEGIN"], else: []) ++
        [to_string(node_count), to_string(edge_count)] ++ Enum.map(entries, &to_string/1)

    graph_command(graph, "GRAPH.BULK", args)
  end

  @spec memory_usage(t(), non_neg_integer() | nil) :: {:ok, term()} | {:error, term()}
  def memory_usage(%__MODULE__{} = graph, samples \\ nil) do
    FalkorDB.command(graph.db, [
      "GRAPH.MEMORY" | CommandBuilder.memory_usage_arguments(graph.name, samples)
    ])
  end

  @spec slowlog(t()) :: {:ok, [map()]} | {:error, term()}
  def slowlog(%__MODULE__{} = graph) do
    with {:ok, reply} <- graph_command(graph, "GRAPH.SLOWLOG") do
      {:ok, parse_slowlog(reply)}
    end
  end

  @spec slowlog_reset(t()) :: {:ok, term()} | {:error, term()}
  def slowlog_reset(%__MODULE__{} = graph), do: graph_command(graph, "GRAPH.SLOWLOG", ["RESET"])

  @spec constraint_create(t(), String.t() | atom(), String.t() | atom(), String.t(), [String.t()]) ::
          {:ok, term()} | {:error, term()}
  def constraint_create(%__MODULE__{} = graph, constraint_type, entity_type, label, properties)
      when is_binary(label) and is_list(properties) do
    args =
      CommandBuilder.constraint_arguments(
        "CREATE",
        normalize_constraint_type(constraint_type),
        normalize_constraint_entity_type(entity_type),
        label,
        properties
      )

    FalkorDB.command(graph.db, ["GRAPH.CONSTRAINT", graph.name | args])
  end

  @spec constraint_drop(t(), String.t() | atom(), String.t() | atom(), String.t(), [String.t()]) ::
          {:ok, term()} | {:error, term()}
  def constraint_drop(%__MODULE__{} = graph, constraint_type, entity_type, label, properties)
      when is_binary(label) and is_list(properties) do
    args =
      CommandBuilder.constraint_arguments(
        "DROP",
        normalize_constraint_type(constraint_type),
        normalize_constraint_entity_type(entity_type),
        label,
        properties
      )

    FalkorDB.command(graph.db, ["GRAPH.CONSTRAINT", graph.name | args])
  end

  @spec close(t()) :: :ok
  def close(%__MODULE__{schema_cache: cache}) when is_pid(cache), do: SchemaCache.stop(cache)

  defp execute_query(graph, command, args) do
    with {:ok, reply} <- graph_command(graph, command, args) do
      Compact.parse(reply, %{
        label: &SchemaCache.resolve_label(graph, &1),
        relationship: &SchemaCache.resolve_relationship(graph, &1),
        property: &SchemaCache.resolve_property(graph, &1)
      })
    end
  end

  defp graph_command(%__MODULE__{db: db, name: name}, command, args \\ []) do
    FalkorDB.command(db, [command, name | Enum.map(args, &to_string/1)])
  end

  defp normalize_constraint_type(value) do
    normalized =
      case value do
        atom when is_atom(atom) -> atom |> Atom.to_string() |> String.upcase()
        binary when is_binary(binary) -> String.upcase(binary)
      end

    if normalized in ["UNIQUE", "MANDATORY"] do
      normalized
    else
      raise ArgumentError, "unsupported constraint type: #{inspect(value)}"
    end
  end

  defp normalize_constraint_entity_type(value) do
    normalized =
      case value do
        atom when is_atom(atom) -> atom |> Atom.to_string() |> String.upcase()
        binary when is_binary(binary) -> String.upcase(binary)
      end

    case normalized do
      "NODE" -> "NODE"
      "EDGE" -> "RELATIONSHIP"
      "RELATIONSHIP" -> "RELATIONSHIP"
      _ -> raise ArgumentError, "unsupported constraint entity type: #{inspect(value)}"
    end
  end

  defp parse_slowlog(reply) when is_list(reply) do
    Enum.reduce(reply, [], fn
      [timestamp, command, query, took], acc ->
        [
          %{
            timestamp: normalize_integer(timestamp),
            command: to_string(command),
            query: to_string(query),
            took: normalize_float(took)
          }
          | acc
        ]

      _entry, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp parse_slowlog(_reply), do: []

  defp normalize_lines(reply) when is_list(reply), do: Enum.map(reply, &to_string/1)
  defp normalize_lines(reply), do: [to_string(reply)]

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(value) when is_binary(value), do: String.to_integer(value)
  defp normalize_integer(value) when is_float(value), do: trunc(value)

  defp normalize_float(value) when is_float(value), do: value
  defp normalize_float(value) when is_integer(value), do: value / 1
  defp normalize_float(value) when is_binary(value), do: String.to_float(value)
end
