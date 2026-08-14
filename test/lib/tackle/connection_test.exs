defmodule Tackle.ConnectionTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest Tackle.Connection, import: true

  setup_all do
    # Forget all opened connections
    Process.whereis(Tackle.Connection) |> Process.exit(:kill)
    :timer.sleep(100)
  end

  test "default connection name returns new process for each call" do
    pid = get_connection_pid(:default)
    assert get_connection_pid(:default) != pid
  end

  test "non default connection name returns same process for each call" do
    pid = get_connection_pid(:foo)
    assert get_connection_pid(:foo) == pid
  end

  test "connection process died -> create new one" do
    pid = get_connection_pid(:bar)
    Process.exit(pid, :kill)
    assert get_connection_pid(:bar) != pid
  end

  def get_connection_pid(name) do
    Tackle.Connection.open(name, "amqp://rabbitmq:5672") |> get_pid
  end

  def get_pid({:ok, connection}) do
    connection |> Map.get(:pid)
  end

  defp log_line(log, marker) do
    log |> String.split("\n") |> Enum.find("", &(&1 =~ marker))
  end

  describe "scrub_url/1" do
    test "removes credentials from a well-formed url while preserving the rest" do
      scrubbed = Tackle.Connection.scrub_url("amqp://user:pass@host:5672/vhost")

      refute scrubbed =~ "pass"
      refute scrubbed =~ "user"
      assert scrubbed == "amqp://host:5672/vhost"
    end

    test "redacts a url that parses to a nil host but still carries credentials" do
      # This url parses with host: nil and the credentials retained in the
      # :authority field, which URI.to_string/1 would otherwise emit verbatim.
      url = "amqp://user:pass@/vhost"

      assert %URI{host: nil, authority: "user:pass@"} = URI.parse(url)

      scrubbed = Tackle.Connection.scrub_url(url)

      assert scrubbed == "[filtered]"
      refute scrubbed =~ "pass"
      refute scrubbed =~ "user"
    end

    test "redacts a schemeless url that parses credentials into the path" do
      # No "//": URI.parse puts "user:pass@host" in :path with a nil host, so
      # rebuilding from parsed fields would round-trip the credentials.
      url = "user:pass@host"

      assert %URI{host: nil} = URI.parse(url)

      scrubbed = Tackle.Connection.scrub_url(url)

      assert scrubbed == "[filtered]"
      refute scrubbed =~ "pass"
      refute scrubbed =~ "user"
    end

    test "fails closed on an unescaped '/' in the password instead of misparsing it into the host" do
      # URI.parse/1 stops consuming userinfo at the first "/", so :host comes
      # back "user" (part of the username) and the rest of the password
      # spills into :path as "/mnOP@rabbit:5672/vh" - a rebuild from those
      # fields alone would produce "amqp://user/mnOP@rabbit:5672/vh",
      # leaking both the username and a password fragment. RabbitMQ
      # passwords are frequently base64, whose alphabet includes "/", so
      # this is a realistic credential, not a contrived one.
      url = "amqp://user:aB3xYzKq7Lp/mnOP@rabbit:5672/vh"

      assert %URI{host: "user", userinfo: nil} = URI.parse(url)

      scrubbed = Tackle.Connection.scrub_url(url)

      assert scrubbed == "[filtered]"
      refute scrubbed =~ "aB3xYzKq7Lp"
      refute scrubbed =~ "user"
      refute scrubbed =~ "@"
    end

    test "fails closed on a raw space in the userinfo" do
      url = "amqp://us er:pa/ss@host:not_a_port/vhost"

      scrubbed = Tackle.Connection.scrub_url(url)

      assert scrubbed == "[filtered]"
      refute scrubbed =~ "us er"
      refute scrubbed =~ "pa/ss"
    end

    test "still redacts (without misparsing) a password containing an embedded '@'" do
      url = "amqp://user:p@ss@host:not_a_port/vhost"

      scrubbed = Tackle.Connection.scrub_url(url)

      refute scrubbed =~ "p@ss"
      refute scrubbed =~ "user"
    end

    test "still redacts (without misparsing) a password containing a double-quote" do
      url = "amqp://user:pa\"ss@host:not_a_port/vhost"

      scrubbed = Tackle.Connection.scrub_url(url)

      refute scrubbed =~ "pa\"ss"
      refute scrubbed =~ "user"
    end
  end

  describe "connection-open failure logging" do
    # These are the two confirmed leak repros: a RabbitMQ password
    # containing an unescaped "/" (realistic - base64 secrets include "/")
    # makes :amqp_uri.parse/2 fail with a reason that embeds the BARE
    # password fragment with no "amqp://" prefix at all (inside an erlang
    # stacktrace argument, e.g. `{:erlang, :list_to_integer, ['<fragment>'],
    # ...}`), so a scheme-anchored scrub over the inspected error term can
    # never reach it. The fix is to never inspect/interpolate the raw error
    # term in the first place - these tests assert the FRAGMENT is absent
    # from the whole captured log, not just that the full password string is
    # gone (checking only the full literal is how the previous, rejected
    # attempt passed its tests while still leaking a substring of it).
    test "the :default path (open_/2) never leaks the password fragment from a malformed uri" do
      log =
        capture_log(fn ->
          assert {:error, _reason} =
                   Tackle.Connection.open(:default, "amqp://user:aB3xYzKq7Lp/mnOP@rabbit:5672/vh")
        end)

      refute log =~ "aB3xYzKq7Lp"

      line = log_line(log, "Failed to open new connection")
      assert line =~ "reason: :unable_to_parse_uri"
      assert line =~ "url: [filtered]"
    end

    test "the open_and_persist/2 path never leaks the password fragment from a malformed uri" do
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:error, _reason} =
                   Tackle.Connection.open(name, "amqp://u:WHOLESECRET/@host/vhost")
        end)

      refute log =~ "WHOLESECRET"

      line = log_line(log, "Failed to open new connection")
      assert line =~ "reason: :unable_to_parse_uri"
      assert line =~ "url: [filtered]"
    end

    test "reopen_on_validation_failure/3 logs a sanitized reason, not the raw validation term" do
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:ok, connection} =
                   Tackle.Connection.reopen_on_validation_failure(
                     {:error, :no_process},
                     name,
                     "amqp://rabbitmq:5672"
                   )

          AMQP.Connection.close(connection)
        end)

      line = log_line(log, "Connection validation failed")
      assert line =~ "reason: :no_process"
      assert line =~ "amqp://rabbitmq:5672"
    end

    test "a non-url-bearing connection error logs the scrubbed url and sanitized reason, without raising" do
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:error, :econnrefused} =
                   Tackle.Connection.open(name, "amqp://user:pass@127.0.0.1:1/vhost")
        end)

      assert log =~ "Failed to open new connection"
      assert log =~ "reason: :econnrefused"
      assert log =~ "amqp://127.0.0.1:1/vhost"
      refute log =~ "user:pass@"
      refute log =~ "user"
      refute log =~ "pass"
    end

    test "a successful connection open still logs a clean, readable struct" do
      log =
        capture_log(fn ->
          assert {:ok, connection} = Tackle.Connection.open(:default, "amqp://rabbitmq:5672")
          AMQP.Connection.close(connection)
        end)

      assert log =~ "Opening new connection"
      assert log =~ "%AMQP.Connection{"
    end
  end
end
