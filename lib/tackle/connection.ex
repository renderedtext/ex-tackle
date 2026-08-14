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

  def open(url) do
    Logger.debug("Connecting to '#{scrub_url(url)}'")

    AMQP.Connection.open(url)
  end

  def open_with_name(url, name) do
    Logger.debug("Connecting to '#{scrub_url(url)}' with name '#{name}'")
    AMQP.Connection.open(url, name: name)
  end

  @doc """
  Returns the given AMQP url with its userinfo component removed, for use in
  log and status output.

  Uses a whitelist rather than blanking individual fields. A well-formed
  `amqp`/`amqps` url (non-nil host) is rebuilt from only its scheme/host/port/path,
  keeping host, port and vhost while dropping userinfo. Anything else - a nil
  host, an unexpected scheme, a schemeless string, or non-binary input - is
  replaced wholesale with a placeholder, since userinfo could otherwise survive
  in another parsed field.
  """
  def scrub_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host, scheme: scheme} = uri
      when is_binary(host) and scheme in ["amqp", "amqps"] ->
        %URI{scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path}
        |> URI.to_string()

      _ ->
        "[filtered]"
    end
  end

  def scrub_url(_url), do: "[filtered]"

  # Renders an arbitrary term (typically a connection-open result like
  # `{:ok, %AMQP.Connection{}}` or `{:error, reason}`) safely for logging, by
  # stripping AMQP userinfo from its inspected form.
  #
  # `reason` terms from a failed connection-open can embed the raw AMQP url -
  # including credentials - as echoed by `:amqp_uri.parse/2` on a malformed
  # url (as a binary or a charlist). Because the url is malformed, its
  # userinfo can legitimately contain unencoded special characters (spaces,
  # slashes, a stray `@`, even the "other" quote character) - exactly the
  # kind of thing that made the url unparseable in the first place. A fixed
  # exclusion set (e.g. "stop at any quote or space") fails open on whichever
  # character it didn't anticipate, so this instead captures the ACTUAL
  # delimiter quote (`'` for a charlist, `"` for a binary/`~c"..."`)
  # immediately preceding `amqp(s)://`, then only that same quote -
  # backreferenced - terminates the run (an escaped `\"`/`\'` pair from
  # `inspect/1` never terminates it either way). Being greedy, it backtracks
  # to the LAST `@` before that boundary - i.e. the real userinfo/host split,
  # even if the userinfo itself contains one. It is a no-op for terms with no
  # such userinfo, so it is safe to apply unconditionally (e.g. to an
  # already-clean `%AMQP.Connection{}` struct).
  defp scrub_term(term) do
    term
    |> inspect()
    |> String.replace(~r{(["'])(amqps?://)(?:\\.|(?!\1)[^\\])*@}, "\\1\\2")
  end

  @doc """
  Get a list of opened connections
  """
  def get_all do
    Agent.get(__MODULE__, fn state -> state |> Map.to_list() end)
  end

  defp open_(name = :default, url) do
    connection = open_with_name(url, Atom.to_string(name))
    Logger.info("Opening new connection #{scrub_term(connection)} for id: #{name}")
    connection
  end

  defp open_(name, url) do
    Agent.get(__MODULE__, fn state -> Map.get(state, name) end)
    |> case do
      nil ->
        open_and_persist(name, url)

      connection ->
        Logger.info("Fetched existing connection #{scrub_term(connection)} for id: #{name}")

        connection
        |> validate(name)
        |> reopen_on_validation_failure(name, url)
    end
  end

  defp open_and_persist(name, url) do
    case open_with_name(url, Atom.to_string(name)) do
      response = {:ok, connection} ->
        Agent.update(__MODULE__, fn state -> Map.put(state, name, connection) end)
        Logger.info("Opening new connection #{scrub_term(connection)} for id: #{name}")
        response

      error ->
        Logger.error("Failed to open new connection for id: #{name}: #{scrub_term(error)}")
        error
    end
  end

  defp validate(connection, name) do
    connection |> Map.get(:pid) |> validate_connection_process(connection, name)
  end

  def reopen_on_validation_failure(state = {:error, _}, name, url) do
    Logger.warning("Connection validation failed #{scrub_term(state)} for id: #{name}")
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
