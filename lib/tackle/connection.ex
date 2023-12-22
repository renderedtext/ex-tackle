defmodule Tackle.Connection do
  require Logger

  @moduledoc """
  Holds established connections.
  Each connection is identifed by name.

  Connection name ':default' is speciall: it is NOT persisted ->
  each open() call with  :default connection name opens new connection
  (to preserve current behaviour).
  """

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Examples:
      open(:default, [])

      open(:foo, [])
  """
  def open(name, url) do
    open_(name, url)
  end

  def open_with_name(url, name) do
    Logger.debug("Connecting to '#{scrub_url(url)}' with name #{name}")

    AMQP.Connection.open(url, name: Atom.to_string(name))
  end

  defp scrub_url(url) do
    url
    |> URI.parse()
    |> Map.put(:userinfo, nil)
    |> URI.to_string()
  end

  @doc """
  Get a list of opened connections
  """
  def get_all do
    Agent.get(__MODULE__, fn state -> state |> Map.to_list() end)
  end

  defp open_(name = :default, url) do
    connection = open_with_name(url, name)
    Logger.info("Opening new connection #{inspect(connection)} for id: #{name}")
    connection
  end

  defp open_(name, url) do
    Agent.get(__MODULE__, fn state -> Map.get(state, name) end)
    |> case do
      nil ->
        open_and_persist(name, url)

      connection ->
        Logger.info("Fetched existing connection #{inspect(connection)} for id: #{name}")

        connection
        |> validate(name)
        |> reopen_on_validation_failure(name, url)
    end
  end

  defp open_and_persist(name, url) do
    case open_with_name(url, name) do
      response = {:ok, connection} ->
        Agent.update(__MODULE__, fn state -> Map.put(state, name, connection) end)
        Logger.info("Opening new connection #{inspect(connection)} for id: #{name}")
        response

      error ->
        Logger.error("Failed to open new connection for id: #{name}: #{error}")
        error
    end
  end

  defp validate(connection, name) do
    connection |> Map.get(:pid) |> validate_connection_process(connection, name)
  end

  def reopen_on_validation_failure(state = {:error, _}, name, url) do
    Logger.warn("Connection validation failed #{inspect(state)} for id: #{name}")
    Agent.update(__MODULE__, fn state -> Map.delete(state, name) end)
    open(name, url)
  end

  def reopen_on_validation_failure(connection, _name, _url) do
    {:ok, connection}
  end

  defp validate_connection_process(pid, connection, name) when is_pid(pid) do
    pid |> Process.alive?() |> validate_connection_process_rh(connection, name)
  end

  defp validate_connection_process(_pid, connection, name) do
    false |> validate_connection_process_rh(connection, name)
  end

  defp validate_connection_process_rh(_alive? = true, connection, _name) do
    connection
  end

  defp validate_connection_process_rh(_alive? = false, _connection, _name) do
    {:error, :no_process}
  end
end
