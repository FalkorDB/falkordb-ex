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
          {:ok, Connection.with(__MODULE__, pid, :sentinel)}

        {:error, reason} ->
          {:error,
           %ConnectionError{message: "Failed to start Redix sentinel connection", reason: reason}}
      end
    end
  end

  @impl true
  def command(pid, command), do: Redix.command(pid, command)

  @impl true
  def pipeline(pid, commands), do: Redix.pipeline(pid, commands)

  @impl true
  def stop(pid), do: Redix.stop(pid)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
