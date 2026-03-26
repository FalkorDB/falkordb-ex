defmodule FalkorDB.TestSupport.FakeAdapter do
  @moduledoc false
  @behaviour FalkorDB.Connection.Adapter

  alias FalkorDB.Connection

  @impl true
  def connect(_opts), do: {:error, :not_supported}

  @impl true
  def command(pid, command) do
    Agent.get_and_update(pid, fn state ->
      updated = %{state | commands: [command | state.commands]}
      response = invoke_responder(updated.responder, {:command, command, updated})
      {normalize_response(response), updated}
    end)
  end

  @impl true
  def pipeline(pid, commands) do
    Agent.get_and_update(pid, fn state ->
      updated = %{state | pipelines: [commands | state.pipelines]}
      response = invoke_responder(updated.responder, {:pipeline, commands, updated})
      {normalize_response(response), updated}
    end)
  end

  @impl true
  def stop(pid), do: Agent.stop(pid)

  def start_link(opts \\ []) do
    responder = Keyword.get(opts, :responder, fn _event -> {:ok, "OK"} end)
    Agent.start_link(fn -> %{responder: responder, commands: [], pipelines: []} end)
  end

  def connection(pid, mode \\ :single) do
    Connection.with(__MODULE__, pid, mode)
  end

  def command_calls(pid), do: Agent.get(pid, fn state -> Enum.reverse(state.commands) end)
  def pipeline_calls(pid), do: Agent.get(pid, fn state -> Enum.reverse(state.pipelines) end)

  def set_responder(pid, responder) when is_function(responder, 1) do
    Agent.update(pid, fn state -> %{state | responder: responder} end)
  end

  defp normalize_response({:ok, _value} = response), do: response
  defp normalize_response({:error, _reason} = response), do: response
  defp normalize_response(value), do: {:ok, value}

  defp invoke_responder(responder, event), do: responder.(event)
end
