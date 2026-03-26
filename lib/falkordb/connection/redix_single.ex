defmodule FalkorDB.Connection.RedixSingle do
  @moduledoc false
  @behaviour FalkorDB.Connection.Adapter

  alias FalkorDB.Connection
  alias FalkorDB.ConnectionError

  @impl true
  def connect(opts) do
    redix_opts = Keyword.get(opts, :redix, [])

    result =
      case Keyword.get(opts, :url) do
        nil ->
          start_opts =
            [
              host: Keyword.get(opts, :host, "127.0.0.1"),
              port: Keyword.get(opts, :port, 6379)
            ]
            |> maybe_put(:database, opts[:database])
            |> maybe_put(:password, opts[:password])
            |> maybe_put(:username, opts[:username])
            |> maybe_put(:name, opts[:name])
            |> maybe_put(:ssl, opts[:ssl])
            |> maybe_put(:socket_opts, opts[:socket_opts])
            |> Keyword.merge(redix_opts)

          Redix.start_link(start_opts)

        url ->
          Redix.start_link(url, redix_opts)
      end

    case result do
      {:ok, pid} ->
        {:ok, Connection.with(__MODULE__, pid, :single)}

      {:error, reason} ->
        {:error,
         %ConnectionError{message: "Failed to start Redix single connection", reason: reason}}
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
