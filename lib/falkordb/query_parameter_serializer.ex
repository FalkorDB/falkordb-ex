defmodule FalkorDB.QueryParameterSerializer do
  @moduledoc """
  Serializes query parameters to FalkorDB CYPHER parameter header format.
  """

  @spec serialize(map()) :: String.t()
  def serialize(params) when is_map(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join(" ", fn {key, value} -> "#{key}=#{serialize_value(value)}" end)
  end

  def serialize(_params), do: raise(ArgumentError, "params must be a map")

  defp serialize_value(nil), do: "null"
  defp serialize_value(value) when is_binary(value), do: ~s("#{escape_string(value)}")
  defp serialize_value(value) when is_integer(value), do: Integer.to_string(value)

  defp serialize_value(value) when is_float(value),
    do: :erlang.float_to_binary(value, [:compact, decimals: 15])

  defp serialize_value(true), do: "true"
  defp serialize_value(false), do: "false"

  defp serialize_value(value) when is_list(value) do
    "[" <> Enum.map_join(value, ",", &serialize_value/1) <> "]"
  end

  defp serialize_value(value) when is_map(value) do
    body =
      value
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join(",", fn {key, inner_value} ->
        "#{key}:#{serialize_value(inner_value)}"
      end)

    "{" <> body <> "}"
  end

  defp serialize_value(value) do
    raise ArgumentError, "unsupported query parameter type: #{inspect(value)}"
  end

  defp escape_string(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
