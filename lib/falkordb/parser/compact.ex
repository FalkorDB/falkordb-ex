defmodule FalkorDB.Parser.Compact do
  @moduledoc false

  alias FalkorDB.ParseError
  alias FalkorDB.QueryResult
  alias FalkorDB.Value.Date, as: DateValue
  alias FalkorDB.Value.DateTime, as: DateTimeValue
  alias FalkorDB.Value.Duration
  alias FalkorDB.Value.Edge
  alias FalkorDB.Value.Node
  alias FalkorDB.Value.Path
  alias FalkorDB.Value.Point
  alias FalkorDB.Value.Time, as: TimeValue

  @value_unknown 0
  @value_null 1
  @value_string 2
  @value_integer 3
  @value_boolean 4
  @value_double 5
  @value_array 6
  @value_edge 7
  @value_node 8
  @value_path 9
  @value_map 10
  @value_point 11
  @value_vectorf32 12
  @value_datetime 13
  @value_date 14
  @value_time 15
  @value_duration 16

  @type resolver_fun :: (integer() -> String.t() | nil)
  @type resolvers :: %{
          optional(:label) => resolver_fun(),
          optional(:relationship) => resolver_fun(),
          optional(:property) => resolver_fun()
        }

  @spec parse(term(), resolvers()) :: {:ok, QueryResult.t()} | {:error, ParseError.t()}
  def parse(reply, resolvers \\ %{}) do
    do_parse(reply, resolvers)
  rescue
    error in [ArgumentError, FunctionClauseError, KeyError] ->
      {:error, %ParseError{message: "Failed parsing compact response", reason: error}}
  end

  defp do_parse_typed_value(@value_null, _value, _resolvers), do: nil
  defp do_parse_typed_value(@value_string, value, _resolvers), do: to_string(value)
  defp do_parse_typed_value(@value_integer, value, _resolvers), do: to_integer(value)
  defp do_parse_typed_value(@value_boolean, value, _resolvers), do: to_boolean(value)
  defp do_parse_typed_value(@value_double, value, _resolvers), do: to_float(value)
  defp do_parse_typed_value(@value_array, value, resolvers), do: parse_array(value, resolvers)
  defp do_parse_typed_value(@value_edge, value, resolvers), do: parse_edge(value, resolvers)
  defp do_parse_typed_value(@value_node, value, resolvers), do: parse_node(value, resolvers)
  defp do_parse_typed_value(@value_path, value, resolvers), do: parse_path(value, resolvers)
  defp do_parse_typed_value(@value_map, value, resolvers), do: parse_map(value, resolvers)
  defp do_parse_typed_value(@value_point, value, _resolvers), do: parse_point(value)
  defp do_parse_typed_value(@value_vectorf32, value, _resolvers), do: parse_vectorf32(value)
  defp do_parse_typed_value(@value_datetime, value, _resolvers), do: parse_datetime_value(value)
  defp do_parse_typed_value(@value_date, value, _resolvers), do: parse_date_value(value)
  defp do_parse_typed_value(@value_time, value, _resolvers), do: parse_time_value(value)

  defp do_parse_typed_value(@value_duration, value, _resolvers),
    do: %Duration{total_seconds: to_integer(value)}

  defp do_parse_typed_value(@value_unknown, value, _resolvers), do: value
  defp do_parse_typed_value(_type, value, _resolvers), do: value

  defp parse_headers(list) when is_list(list) do
    Enum.map(list, fn
      [_type, name] -> to_string(name)
      other -> to_string(other)
    end)
  end

  defp parse_headers(_headers), do: []

  defp parse_rows(list, headers, resolvers) when is_list(list) do
    Enum.map(list, &parse_row(&1, headers, resolvers))
  end

  defp parse_rows(_rows, _headers, _resolvers), do: []

  defp parse_row(row, headers, resolvers) when is_list(row) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {cell, index}, acc ->
      key = Enum.at(headers, index, Integer.to_string(index))
      Map.put(acc, key, parse_value(cell, resolvers))
    end)
  end

  defp parse_row(_row, _headers, _resolvers), do: %{}

  defp do_parse([metadata], _resolvers) when is_list(metadata) do
    normalized = normalize_metadata(metadata)

    {:ok,
     %QueryResult{
       headers: nil,
       data: nil,
       stats: parse_stats(normalized),
       metadata: normalized
     }}
  end

  defp do_parse(reply, resolvers) when is_list(reply) do
    headers_raw = Enum.at(reply, 0, [])
    rows_raw = Enum.at(reply, 1, [])
    metadata_raw = Enum.at(reply, 2, [])

    headers = parse_headers(headers_raw)
    data = parse_rows(rows_raw, headers, resolvers)

    metadata = normalize_metadata(metadata_raw)

    {:ok,
     %QueryResult{
       headers: headers,
       data: data,
       stats: parse_stats(metadata),
       metadata: metadata
     }}
  end

  defp do_parse(reply, _resolvers) do
    {:error, %ParseError{message: "Unexpected compact reply shape", reason: reply}}
  end

  defp parse_value(raw_value, resolvers) do
    case raw_value do
      [type, value] ->
        parse_typed_value(type, value, resolvers)

      value ->
        value
    end
  end

  defp parse_typed_value(type, value, resolvers) do
    type
    |> to_integer()
    |> do_parse_typed_value(value, resolvers)
  end

  defp parse_array(value, resolvers) when is_list(value) do
    Enum.map(value, &parse_value(&1, resolvers))
  end

  defp parse_array(_value, _resolvers), do: []

  defp parse_map(value, resolvers) when is_list(value) do
    value
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn
      [key, raw], acc ->
        Map.put(acc, to_string(key), parse_value(raw, resolvers))

      _pair, acc ->
        acc
    end)
  end

  defp parse_map(_value, _resolvers), do: %{}

  defp parse_point([latitude, longitude]) do
    %Point{latitude: to_float(latitude), longitude: to_float(longitude)}
  end

  defp parse_point(_value), do: %Point{latitude: 0.0, longitude: 0.0}

  defp parse_vectorf32(value) when is_list(value), do: Enum.map(value, &to_float/1)
  defp parse_vectorf32(_value), do: []

  defp parse_node([id, label_ids, raw_properties], resolvers) do
    labels =
      if is_list(label_ids) do
        Enum.map(label_ids, fn label_id ->
          resolve(resolvers, :label, label_id, "unknown_label_")
        end)
      else
        []
      end

    %Node{
      id: to_integer(id),
      labels: labels,
      properties: parse_entity_properties(raw_properties, resolvers)
    }
  end

  defp parse_node(_value, _resolvers), do: %Node{id: 0, labels: [], properties: %{}}

  defp parse_edge(
         [id, relationship_type_id, source_id, destination_id, raw_properties],
         resolvers
       ) do
    %Edge{
      id: to_integer(id),
      relationship_type:
        resolve(resolvers, :relationship, relationship_type_id, "unknown_relationship_"),
      source_id: to_integer(source_id),
      destination_id: to_integer(destination_id),
      properties: parse_entity_properties(raw_properties, resolvers)
    }
  end

  defp parse_edge(_value, _resolvers) do
    %Edge{
      id: 0,
      relationship_type: "unknown_relationship_0",
      source_id: 0,
      destination_id: 0,
      properties: %{}
    }
  end

  defp parse_path([nodes_raw, edges_raw], resolvers) do
    nodes =
      case parse_value(nodes_raw, resolvers) do
        parsed when is_list(parsed) -> Enum.filter(parsed, &match?(%Node{}, &1))
        _ -> []
      end

    edges =
      case parse_value(edges_raw, resolvers) do
        parsed when is_list(parsed) -> Enum.filter(parsed, &match?(%Edge{}, &1))
        _ -> []
      end

    %Path{nodes: nodes, edges: edges}
  end

  defp parse_path(_value, _resolvers), do: %Path{nodes: [], edges: []}

  defp parse_entity_properties(raw_properties, resolvers) when is_list(raw_properties) do
    Enum.reduce(raw_properties, %{}, fn
      [property_id, value_type, value], acc ->
        property_name = resolve(resolvers, :property, property_id, "unknown_property_")
        Map.put(acc, property_name, parse_value([value_type, value], resolvers))

      [property_id, [value_type, value]], acc ->
        property_name = resolve(resolvers, :property, property_id, "unknown_property_")
        Map.put(acc, property_name, parse_value([value_type, value], resolvers))

      _other, acc ->
        acc
    end)
  end

  defp parse_entity_properties(_raw_properties, _resolvers), do: %{}

  defp resolve(resolvers, type, id, unknown_prefix) do
    resolver = Map.get(resolvers, type, fn _ -> nil end)
    resolved = resolver.(to_integer(id))
    resolved || "#{unknown_prefix}#{to_integer(id)}"
  end

  defp parse_datetime_value(value) do
    unix_seconds = to_integer(value)
    datetime = DateTime.from_unix!(unix_seconds)
    %DateTimeValue{unix_seconds: unix_seconds, value: datetime}
  end

  defp parse_date_value(value) do
    unix_seconds = to_integer(value)
    date = unix_seconds |> DateTime.from_unix!() |> DateTime.to_date()
    %DateValue{unix_seconds: unix_seconds, value: date}
  end

  defp parse_time_value(value) do
    unix_seconds = to_integer(value)
    time = unix_seconds |> DateTime.from_unix!() |> DateTime.to_time()
    %TimeValue{unix_seconds: unix_seconds, value: time}
  end

  defp normalize_metadata(metadata) when is_list(metadata), do: Enum.map(metadata, &to_string/1)
  defp normalize_metadata(_metadata), do: []

  defp parse_stats(metadata_lines) do
    Enum.reduce(metadata_lines, %{}, fn line, acc ->
      case Regex.run(~r/^(.+?):\s*(.+)$/, line) do
        [_, raw_key, raw_value] ->
          key =
            raw_key
            |> String.trim()
            |> String.downcase()
            |> String.replace(~r/[\s-]+/, "_")

          Map.put(acc, key, parse_stat_value(raw_value))

        _ ->
          acc
      end
    end)
  end

  defp parse_stat_value(value) do
    trimmed = String.trim(to_string(value))
    lower = String.downcase(trimmed)

    cond do
      lower == "true" ->
        true

      lower == "false" ->
        false

      Regex.match?(~r/^-?\d+$/, trimmed) ->
        String.to_integer(trimmed)

      Regex.match?(
        ~r/^-?\d*\.?\d+(?:\s*(?:ms|s|sec|secs|second|seconds|milliseconds))?$/i,
        trimmed
      ) ->
        numeric =
          Regex.replace(~r/\s*(?:ms|s|sec|secs|second|seconds|milliseconds)\s*$/i, trimmed, "")

        if String.contains?(numeric, ".") do
          String.to_float(numeric)
        else
          String.to_integer(numeric)
        end

      true ->
        trimmed
    end
  end

  defp to_integer(value) when is_integer(value), do: value
  defp to_integer(value) when is_float(value), do: trunc(value)
  defp to_integer(value) when is_binary(value), do: String.to_integer(value)
  defp to_integer(value), do: value |> to_string() |> String.to_integer()

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value / 1

  defp to_float(value) when is_binary(value) do
    trimmed = String.trim(value)

    case Float.parse(trimmed) do
      {number, ""} ->
        number

      _ ->
        case Integer.parse(trimmed) do
          {number, ""} -> number / 1
          _ -> raise ArgumentError, "not a textual representation of a float"
        end
    end
  end

  defp to_float(value), do: value |> to_string() |> String.to_float()

  defp to_boolean(value) when is_boolean(value), do: value
  defp to_boolean(value) when is_integer(value), do: value != 0
  defp to_boolean(value) when is_binary(value), do: String.downcase(value) == "true"
  defp to_boolean(value), do: value in [true, "true", 1]
end
