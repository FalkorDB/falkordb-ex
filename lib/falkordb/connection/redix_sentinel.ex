defmodule FalkorDB.Connection.RedixSentinel do
  @moduledoc false
  @behaviour FalkorDB.Connection.Adapter

  alias FalkorDB.Connection
  alias FalkorDB.ConnectionError

  @impl true
  def connect(opts) do
    sentinel_opts = Keyword.get(opts, :sentinel, [])
    sentinels = Keyword.get(opts, :sentinels, Keyword.get(sentinel_opts, :sentinels, []))
    group = Keyword.get(opts, :group, Keyword.get(sentinel_opts, :group, "mymaster"))
    role = Keyword.get(opts, :role, Keyword.get(sentinel_opts, :role, :primary))

    if sentinels == [] do
      {:error,
       %ConnectionError{
         message: "sentinels cannot be empty for sentinel mode",
         reason: :missing_sentinels
       }}
    else
      case normalize_sentinels(sentinels) do
        {:ok, normalized} ->
          start_sentinel(opts, normalized, group, role)

        {:error, reason} ->
          {:error,
           %ConnectionError{
             message: "invalid sentinel address: #{inspect(reason)}",
             reason: reason
           }}
      end
    end
  end

  # Redix accepts URI strings or keyword lists, not bare {host, port} tuples.
  # Normalize the common FalkorDB client shapes so callers and env helpers keep working.
  @doc false
  def normalize_sentinels(sentinels) when is_list(sentinels) do
    sentinels
    |> Enum.reduce_while({:ok, []}, fn address, {:ok, acc} ->
      case normalize_sentinel_address(address) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      other -> other
    end
  end

  def normalize_sentinels(other), do: {:error, {:invalid_sentinels, other}}

  @doc false
  def normalize_sentinel_address(address) when is_binary(address) do
    cond do
      String.starts_with?(address, "redis://") or String.starts_with?(address, "rediss://") ->
        {:ok, address}

      true ->
        case String.split(address, ":", parts: 2) do
          [host, port] ->
            case Integer.parse(port) do
              {port_number, ""} when port_number in 1..65_535 ->
                {:ok, [host: host, port: port_number]}

              _ ->
                {:error, {:invalid_port, address}}
            end

          [host] when host != "" ->
            {:ok, [host: host, port: 26_379]}

          _ ->
            {:error, {:invalid_address, address}}
        end
    end
  end

  def normalize_sentinel_address({host, port})
      when is_binary(host) and is_integer(port) and port in 1..65_535 do
    {:ok, [host: host, port: port]}
  end

  def normalize_sentinel_address(address) when is_list(address) do
    if Keyword.keyword?(address) and Keyword.has_key?(address, :host) do
      {:ok, address}
    else
      {:error, {:invalid_address, address}}
    end
  end

  def normalize_sentinel_address(other), do: {:error, {:invalid_address, other}}

  defp start_sentinel(opts, sentinels, group, role) do
    redix_opts = Keyword.get(opts, :redix, [])

    connection_opts =
      [sentinel: [sentinels: sentinels, group: group, role: role]]
      |> maybe_put(:name, opts[:name])
      |> maybe_put(:password, opts[:password])
      |> maybe_put(:username, opts[:username])
      |> maybe_put(:database, opts[:database])
      |> maybe_put(:ssl, opts[:ssl])
      |> maybe_put(:socket_opts, opts[:socket_opts])
      |> Keyword.merge(redix_opts)

    case Redix.start_link(connection_opts) do
      {:ok, pid} ->
        {:ok, Connection.with(__MODULE__, pid, :sentinel, Connection.timeout_from_opts(opts))}

      {:error, reason} ->
        {:error,
         %ConnectionError{message: "Failed to start Redix sentinel connection", reason: reason}}
    end
  end

  @impl true
  def command(pid, command, timeout), do: Redix.command(pid, command, timeout: timeout)

  @impl true
  def pipeline(pid, commands, timeout), do: Redix.pipeline(pid, commands, timeout: timeout)

  @impl true
  def stop(pid), do: Redix.stop(pid)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
