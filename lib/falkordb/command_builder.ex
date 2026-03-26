defmodule FalkorDB.CommandBuilder do
  @moduledoc false

  alias FalkorDB.QueryParameterSerializer

  @spec query_arguments(String.t(), keyword() | map() | integer() | nil, boolean()) :: [
          String.t()
        ]
  def query_arguments(query, options \\ nil, compact \\ true) when is_binary(query) do
    {query_argument, timeout, version} =
      case options do
        nil ->
          {query, nil, nil}

        timeout when is_integer(timeout) ->
          {query, timeout, nil}

        opts when is_list(opts) or is_map(opts) ->
          {params, timeout, version} = extract_query_options(opts)

          query_argument =
            case params do
              %{} = non_empty when map_size(non_empty) > 0 ->
                "CYPHER #{QueryParameterSerializer.serialize(non_empty)} #{query}"

              _ ->
                query
            end

          {query_argument, timeout, version}
      end

    [query_argument]
    |> maybe_append_timeout(timeout)
    |> maybe_append_version(version)
    |> maybe_append_compact(compact)
  end

  @spec memory_usage_arguments(String.t(), integer() | nil) :: [String.t()]
  def memory_usage_arguments(graph_name, samples \\ nil) when is_binary(graph_name) do
    ["USAGE", graph_name]
    |> maybe_append_samples(samples)
  end

  @spec constraint_arguments(String.t(), String.t(), String.t(), String.t(), [String.t()]) :: [
          String.t()
        ]
  def constraint_arguments(action, constraint_type, entity_type, label, properties)
      when is_binary(action) and is_binary(constraint_type) and is_binary(entity_type) and
             is_binary(label) and is_list(properties) do
    [
      String.upcase(action),
      String.upcase(constraint_type),
      String.upcase(entity_type),
      label,
      "PROPERTIES",
      Integer.to_string(length(properties))
      | Enum.map(properties, &to_string/1)
    ]
  end

  @spec udf_load_arguments(String.t(), String.t(), boolean()) :: [String.t()]
  def udf_load_arguments(library_name, script, replace \\ false)
      when is_binary(library_name) and is_binary(script) do
    ["LOAD"]
    |> maybe_append_replace(replace)
    |> Kernel.++([library_name, script])
  end

  @spec udf_list_arguments(String.t() | nil, boolean()) :: [String.t()]
  def udf_list_arguments(library_name \\ nil, with_code \\ false) do
    ["LIST"]
    |> maybe_append_library(library_name)
    |> maybe_append_with_code(with_code)
  end

  @spec password_arguments(String.t(), String.t()) :: [String.t()]
  def password_arguments(action, password) when is_binary(action) and is_binary(password) do
    [String.upcase(action), password]
  end

  defp extract_query_options(options) do
    getter =
      if is_list(options) do
        fn key -> Keyword.get(options, key) end
      else
        fn key -> Map.get(options, key) end
      end

    params = getter.(:params) || getter.("params") || %{}
    timeout = getter.(:timeout) || getter.("timeout") || getter.(:TIMEOUT) || getter.("TIMEOUT")
    version = getter.(:version) || getter.("version")
    {params, timeout, version}
  end

  defp maybe_append_timeout(args, nil), do: args
  defp maybe_append_timeout(args, timeout), do: args ++ ["TIMEOUT", to_string(timeout)]

  defp maybe_append_version(args, nil), do: args
  defp maybe_append_version(args, version), do: args ++ ["version", to_string(version)]

  defp maybe_append_compact(args, false), do: args
  defp maybe_append_compact(args, true), do: args ++ ["--compact"]

  defp maybe_append_samples(args, nil), do: args
  defp maybe_append_samples(args, samples), do: args ++ ["SAMPLES", to_string(samples)]

  defp maybe_append_replace(args, false), do: args
  defp maybe_append_replace(args, true), do: args ++ ["REPLACE"]

  defp maybe_append_library(args, nil), do: args
  defp maybe_append_library(args, library_name), do: args ++ [library_name]

  defp maybe_append_with_code(args, false), do: args
  defp maybe_append_with_code(args, true), do: args ++ ["WITHCODE"]
end
