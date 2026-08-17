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

  Fails closed: this only ever returns a rebuilt `scheme://host:port/path`
  when the parse is unambiguous and no userinfo can possibly have survived
  into another field. A well-formed url has any credentials captured
  entirely into `URI.parse/1`'s `:userinfo` field, which is dropped when
  rebuilding. But `URI.parse/1` splits userinfo from host on the *last*
  `@`, using a fairly permissive definition of "host" - an unescaped `/` in
  the password (common with base64 secrets) makes it stop consuming at that
  `/` instead, so `:userinfo` comes back `nil` while credential fragments
  spill into `:host`/`:path` instead (e.g. `"amqp://user:pa/ss@host"` parses
  to `host: "user"`, `path: "/ss@host"` - a naive rebuild from those fields
  would leak "user" and "ss" right back out). So: whenever the raw url
  contains an `@` at all, a `nil` userinfo means the parse is ambiguous, not
  credential-free, and this returns the placeholder instead of guessing.
  Anything else non-canonical - a nil host, an unexpected scheme, a
  schemeless string, non-binary input, or (belt and suspenders) an `@`
  surviving into the rebuilt string - is also replaced wholesale. Losing
  host/vhost on a malformed url is an acceptable cost; leaking is not.
  """
  def scrub_url(url) when is_binary(url) do
    uri = URI.parse(url)

    with true <- is_binary(uri.host),
         true <- uri.scheme in ["amqp", "amqps"],
         true <- credentials_fully_captured?(url, uri.userinfo) do
      rebuilt =
        %URI{scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path}
        |> URI.to_string()

      if String.contains?(rebuilt, "@"), do: "[filtered]", else: rebuilt
    else
      _ -> "[filtered]"
    end
  end

  def scrub_url(_url), do: "[filtered]"

  defp credentials_fully_captured?(url, userinfo) do
    if String.contains?(url, "@") do
      is_binary(userinfo)
    else
      is_nil(userinfo)
    end
  end

  # Reduces a connection-open (or validation) failure to a coarse, safe
  # classification for logging - NEVER the raw term.
  #
  # A `{:error, reason}` from a failed connection-open can embed the raw
  # AMQP url - including credentials - deep inside `reason` in more than one
  # place: `:amqp_uri.parse/2` echoes the malformed url verbatim into a
  # `:malformed_uri` tuple, and separately scatters a BARE password fragment
  # (no `amqp://` prefix at all) into an erlang stacktrace argument list via
  # `:erlang.list_to_integer/1`. There is no fixed set of "safe" positions to
  # pluck out of that shape - and no regex over its `inspect/1` form can
  # reliably find every one either, which is exactly how the previous
  # attempt at this still leaked - so this never descends into tuple
  # contents beyond the leading tag: it unwraps one `{:error, _}` layer,
  # then repeatedly takes `elem(0)` of whatever tuple remains until it hits
  # an atom (or gives up). No binary, charlist, list, or nested tuple ever
  # reaches the log.
  defp sanitize_reason({:error, reason}), do: sanitize_reason(reason)
  defp sanitize_reason(reason) when is_atom(reason), do: reason

  defp sanitize_reason(reason) when is_tuple(reason) and tuple_size(reason) > 0 do
    reason |> elem(0) |> sanitize_reason()
  end

  defp sanitize_reason(_reason), do: :connection_error

  @doc """
  Get a list of opened connections
  """
  def get_all do
    Agent.get(__MODULE__, fn state -> state |> Map.to_list() end)
  end

  defp open_(name = :default, url) do
    case open_with_name(url, Atom.to_string(name)) do
      response = {:ok, connection} ->
        Logger.info("Opening new connection #{inspect(connection)} for id: #{name}")
        response

      error ->
        Logger.error(
          "Failed to open new connection for id: #{name}, url: #{scrub_url(url)}, reason: #{inspect(sanitize_reason(error))}"
        )

        error
    end
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
    case open_with_name(url, Atom.to_string(name)) do
      response = {:ok, connection} ->
        Agent.update(__MODULE__, fn state -> Map.put(state, name, connection) end)
        Logger.info("Opening new connection #{inspect(connection)} for id: #{name}")
        response

      error ->
        Logger.error(
          "Failed to open new connection for id: #{name}, url: #{scrub_url(url)}, reason: #{inspect(sanitize_reason(error))}"
        )

        error
    end
  end

  defp validate(connection, name) do
    connection |> Map.get(:pid) |> validate_connection_process(connection, name)
  end

  def reopen_on_validation_failure(state = {:error, _}, name, url) do
    Logger.warning(
      "Connection validation failed for id: #{name}, url: #{scrub_url(url)}, reason: #{inspect(sanitize_reason(state))}"
    )

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
