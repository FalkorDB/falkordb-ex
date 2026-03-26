defmodule FalkorDB.SchemaCache do
  @moduledoc false

  alias FalkorDB.Graph

  @type t :: pid()

  @spec new() :: t()
  def new do
    {:ok, pid} = Agent.start_link(fn -> empty_state() end)
    pid
  end

  @spec clear(t()) :: :ok
  def clear(pid) when is_pid(pid) do
    Agent.update(pid, fn _ -> empty_state() end)
  end

  @spec stop(t()) :: :ok
  def stop(pid) when is_pid(pid), do: Agent.stop(pid)

  @spec resolve_label(Graph.t(), integer()) :: String.t() | nil
  def resolve_label(graph, index), do: resolve(graph, :labels, index, "CALL db.labels()")

  @spec resolve_relationship(Graph.t(), integer()) :: String.t() | nil
  def resolve_relationship(graph, index),
    do: resolve(graph, :relationships, index, "CALL db.relationshipTypes()")

  @spec resolve_property(Graph.t(), integer()) :: String.t() | nil
  def resolve_property(graph, index),
    do: resolve(graph, :properties, index, "CALL db.propertyKeys()")

  defp resolve(%Graph{schema_cache: cache} = graph, key, index, query) do
    index = normalize_index(index)

    case Agent.get(cache, fn state -> Map.get(state, key, %{}) |> Map.get(index) end) do
      nil ->
        refresh(graph, key, query)
        Agent.get(cache, fn state -> Map.get(state, key, %{}) |> Map.get(index) end)

      value ->
        value
    end
  end

  defp refresh(%Graph{schema_cache: cache} = graph, key, query) do
    values =
      case Graph.ro_query(graph, query) do
        {:ok, result} -> extract_first_column(result.data)
        _ -> []
      end

    mapped =
      values
      |> Enum.with_index()
      |> Enum.into(%{}, fn {value, index} -> {index, to_string(value)} end)

    Agent.update(cache, fn state -> Map.put(state, key, mapped) end)
  end

  defp extract_first_column(nil), do: []

  defp extract_first_column(rows) when is_list(rows) do
    Enum.map(rows, fn row ->
      row
      |> Map.values()
      |> List.first()
    end)
  end

  defp empty_state do
    %{labels: %{}, relationships: %{}, properties: %{}}
  end

  defp normalize_index(index) when is_integer(index), do: index
  defp normalize_index(index) when is_binary(index), do: String.to_integer(index)
  defp normalize_index(index), do: index |> to_string() |> String.to_integer()
end
