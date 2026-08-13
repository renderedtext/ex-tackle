defmodule Tackle.ConnectionTest do
  use ExUnit.Case
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
end
