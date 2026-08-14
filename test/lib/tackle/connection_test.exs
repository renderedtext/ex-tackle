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
  end

  describe "connection-open failure logging" do
    # A malformed url (illegal port section) makes :amqp_uri.parse echo the
    # raw url - credentials included - back inside the {:error, reason} term.
    # See :amqp_uri.parse/2 / uri_parser.erl for the shape of the crash it
    # embeds.
    @malformed_credentialed_url "amqp://user:pa/ss@host/vhost"

    # Every open attempt also logs a separate "Connecting to '...'" debug
    # line (open_with_name/2) built from scrub_url/1 on the *raw input url*,
    # not from scrub_term/1 on the *error term* - a different helper on a
    # different value entirely. These tests are about scrub_term, so they
    # assert against the specific "Opening.../Failed..." line it produces
    # (via log_line/2), rather than the whole captured log, to stay isolated
    # from that other code path.
    test "the :default path (open_/2) scrubs credentials from the error it logs" do
      log =
        capture_log(fn ->
          assert {:error, _reason} = Tackle.Connection.open(:default, @malformed_credentialed_url)
        end)

      line = log_line(log, "Opening new connection")
      refute line =~ "pa/ss"
      assert line =~ "amqp://host/vhost"
    end

    test "the open_and_persist/2 error path scrubs credentials and does not raise" do
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:error, _reason} = Tackle.Connection.open(name, @malformed_credentialed_url)
        end)

      line = log_line(log, "Failed to open new connection")
      refute line =~ "pa/ss"
      assert line =~ "amqp://host/vhost"
    end

    # A naive scrub that stops at the first "special" character in the
    # userinfo fails open on exactly these two shapes: a raw space, and a
    # stray "@" inside the credentials. Both are realistic for a malformed
    # (hence unencoded) url, and both previously either leaked the whole url
    # (space) or leaked a fragment of the password (embedded "@").
    test "the :default path scrubs a credentialed url with a space in the userinfo" do
      url = "amqp://us er:pa/ss@host:not_a_port/vhost"

      log =
        capture_log(fn ->
          assert {:error, _reason} = Tackle.Connection.open(:default, url)
        end)

      line = log_line(log, "Opening new connection")
      refute line =~ "us er"
      refute line =~ "pa/ss"
      assert line =~ "amqp://host:not_a_port/vhost"
    end

    test "the open_and_persist/2 path scrubs a credentialed url with an embedded '@' in the password" do
      url = "amqp://user:p@ss@host:not_a_port/vhost"
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:error, _reason} = Tackle.Connection.open(name, url)
        end)

      line = log_line(log, "Failed to open new connection")
      refute line =~ "p@ss"
      refute line =~ "user:p"
      assert line =~ "amqp://host:not_a_port/vhost"
    end

    # The raw url gets echoed back as a *charlist* (single-quote delimited in
    # inspect/1's output), so a literal double-quote in the credentials is
    # not a real terminator - only an unescaped single-quote is. A scrub that
    # treats "any quote character" as a hard stop, rather than the actual
    # enclosing delimiter, fails open here exactly like it did on the space
    # and embedded-"@" cases above.
    test "the :default path scrubs a credentialed url with a double-quote in the password" do
      url = "amqp://user:pa\"ss@host:not_a_port/vhost"

      log =
        capture_log(fn ->
          assert {:error, _reason} = Tackle.Connection.open(:default, url)
        end)

      line = log_line(log, "Opening new connection")
      refute line =~ "pa\"ss"
      refute line =~ "user:pa"
      assert line =~ "amqp://host:not_a_port/vhost"
    end

    test "a non-url-bearing connection error is logged as-is and does not raise" do
      name = :"leak_regression_#{System.unique_integer([:positive])}"

      log =
        capture_log(fn ->
          assert {:error, :econnrefused} =
                   Tackle.Connection.open(name, "amqp://user:pass@127.0.0.1:1/vhost")
        end)

      assert log =~ "Failed to open new connection"
      assert log =~ ":econnrefused"
      refute log =~ "user:pass@"
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
