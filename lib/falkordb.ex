defmodule FalkorDB do
  @moduledoc """
  Elixir client for FalkorDB 4.16.x using Redix as the Redis transport.

  V1 supports single-node and sentinel topologies.
  """

  alias FalkorDB.CommandBuilder
  alias FalkorDB.CommandError
  alias FalkorDB.Connection
  alias FalkorDB.Connection.RedixSentinel
  alias FalkorDB.Connection.RedixSingle
  alias FalkorDB.Graph

  @type t :: %__MODULE__{
          connection: Connection.t(),
          topology: Connection.mode()
        }

  defstruct [:connection, :topology]

  @spec connect(keyword()) :: {:ok, t()} | {:error, term()}
  def connect(opts \\ []) do
    mode = normalize_mode(Keyword.get(opts, :mode, :single))
    adapter = adapter_for(mode)

    with {:ok, connection} <- adapter.connect(opts) do
      {:ok, %__MODULE__{connection: connection, topology: mode}}
    end
  end

  @spec from_connection(Connection.t()) :: t()
  def from_connection(%Connection{} = connection) do
    %__MODULE__{connection: connection, topology: connection.mode}
  end

  @spec mode(t()) :: Connection.mode()
  def mode(%__MODULE__{topology: mode}), do: mode

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{connection: connection}), do: Connection.stop(connection)

  @spec select_graph(t(), String.t()) :: Graph.t()
  def select_graph(%__MODULE__{} = db, graph_name), do: Graph.new(db, graph_name)

  @spec command(t(), [String.Chars.t()]) :: {:ok, term()} | {:error, term()}
  def command(%__MODULE__{connection: connection}, command) do
    case Connection.command(connection, command) do
      {:error, %Redix.Error{} = error} ->
        {:error, %CommandError{message: Exception.message(error), reason: error}}

      {:error, %Redix.ConnectionError{} = error} ->
        {:error, %FalkorDB.ConnectionError{message: Exception.message(error), reason: error}}

      other ->
        other
    end
  end

  @spec pipeline(t(), [[String.Chars.t()]]) :: {:ok, [term()]} | {:error, term()}
  def pipeline(%__MODULE__{connection: connection}, commands) do
    case Connection.pipeline(connection, commands) do
      {:error, %Redix.Error{} = error} ->
        {:error, %CommandError{message: Exception.message(error), reason: error}}

      {:error, %Redix.ConnectionError{} = error} ->
        {:error, %FalkorDB.ConnectionError{message: Exception.message(error), reason: error}}

      other ->
        other
    end
  end

  @spec list(t()) :: {:ok, [String.t()]} | {:error, term()}
  def list(%__MODULE__{} = db) do
    with {:ok, reply} <- command(db, ["GRAPH.LIST"]) do
      {:ok, normalize_string_list(reply)}
    end
  end

  @spec config_get(t(), String.t()) :: {:ok, term()} | {:error, term()}
  def config_get(%__MODULE__{} = db, key) when is_binary(key) do
    command(db, ["GRAPH.CONFIG", "GET", key])
  end

  @spec config_set(t(), String.t(), String.Chars.t()) :: {:ok, term()} | {:error, term()}
  def config_set(%__MODULE__{} = db, key, value) when is_binary(key) do
    command(db, ["GRAPH.CONFIG", "SET", key, to_string(value)])
  end

  @spec info(t(), [String.t()] | String.t() | nil) :: {:ok, term()} | {:error, term()}
  def info(db, sections \\ nil)

  def info(%__MODULE__{} = db, nil), do: command(db, ["GRAPH.INFO"])

  def info(%__MODULE__{} = db, section) when is_binary(section),
    do: command(db, ["GRAPH.INFO", section])

  def info(%__MODULE__{} = db, sections) when is_list(sections) do
    command(db, ["GRAPH.INFO" | Enum.map(sections, &to_string/1)])
  end

  @spec debug(t(), [String.Chars.t()]) :: {:ok, term()} | {:error, term()}
  def debug(%__MODULE__{} = db, args) when is_list(args) do
    command(db, ["GRAPH.DEBUG" | Enum.map(args, &to_string/1)])
  end

  @spec acl(t(), [String.Chars.t()]) :: {:ok, term()} | {:error, term()}
  def acl(%__MODULE__{} = db, args) when is_list(args) do
    command(db, ["GRAPH.ACL" | Enum.map(args, &to_string/1)])
  end

  @spec set_password(t(), String.t() | atom(), String.t()) :: {:ok, term()} | {:error, term()}
  def set_password(%__MODULE__{} = db, action, password) when is_binary(password) do
    [normalized_action, pass] =
      CommandBuilder.password_arguments(normalize_action(action), password)

    command(db, ["GRAPH.PASSWORD", normalized_action, pass])
  end

  @spec udf_load(t(), String.t(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def udf_load(%__MODULE__{} = db, library_name, script, opts \\ []) do
    replace = Keyword.get(opts, :replace, false)
    command(db, ["GRAPH.UDF" | CommandBuilder.udf_load_arguments(library_name, script, replace)])
  end

  @spec udf_list(t(), String.t() | nil, keyword()) :: {:ok, term()} | {:error, term()}
  def udf_list(%__MODULE__{} = db, library_name \\ nil, opts \\ []) do
    with_code = Keyword.get(opts, :with_code, false)
    command(db, ["GRAPH.UDF" | CommandBuilder.udf_list_arguments(library_name, with_code)])
  end

  @spec udf_flush(t()) :: {:ok, term()} | {:error, term()}
  def udf_flush(%__MODULE__{} = db), do: command(db, ["GRAPH.UDF", "FLUSH"])

  @spec udf_delete(t(), String.t()) :: {:ok, term()} | {:error, term()}
  def udf_delete(%__MODULE__{} = db, library_name),
    do: command(db, ["GRAPH.UDF", "DELETE", library_name])

  defp adapter_for(:single), do: RedixSingle
  defp adapter_for(:sentinel), do: RedixSentinel

  defp normalize_mode(mode) when is_atom(mode) do
    case mode do
      :single -> :single
      :sentinel -> :sentinel
      _ -> raise ArgumentError, "unsupported mode: #{inspect(mode)}"
    end
  end

  defp normalize_mode(mode) when is_binary(mode) do
    case String.downcase(mode) do
      "single" -> :single
      "sentinel" -> :sentinel
      _ -> raise ArgumentError, "unsupported mode: #{inspect(mode)}"
    end
  end

  defp normalize_string_list(list) when is_list(list), do: Enum.map(list, &to_string/1)
  defp normalize_string_list(_other), do: []

  defp normalize_action(action) when is_atom(action),
    do: action |> Atom.to_string() |> String.upcase()

  defp normalize_action(action) when is_binary(action), do: String.upcase(action)
end
