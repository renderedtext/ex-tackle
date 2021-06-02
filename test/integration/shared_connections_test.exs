defmodule Tackle.SharedConnection.Test do
  use ExSpec

  defmodule TestConsumer1 do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-multiple-channels-exchange-1",
      routing_key: "multiple-channels",
      service: "multiple-channels-service-1",
      connection_id: :single_connection

    def handle_message(message) do
      Tackle.SharedConnection.Test.message_handler(message, "consumer_1")
    end
  end

  defmodule TestConsumer2 do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-multiple-channels-exchange-2",
      routing_key: "multiple-channels",
      service: "multiple-channels-service-2",
      connection_id: :single_connection

    def handle_message(message) do
      Tackle.SharedConnection.Test.message_handler(message, "consumer_2")
    end
  end

  def message_handler(message, response) do
    "#PID" <> pid = message
    client = pid |> String.to_charlist() |> :erlang.list_to_pid()
    send(client, response)
  end

  @publish_options_1 %{
    url: "amqp://localhost",
    exchange: "test-multiple-channels-exchange-1",
    routing_key: "multiple-channels"
  }

  @publish_options_2 %{
    url: "amqp://localhost",
    exchange: "test-multiple-channels-exchange-2",
    routing_key: "multiple-channels"
  }

  setup_all do
    # Forget all opened connections
    Process.whereis(Tackle.Connection) |> Process.exit(:kill)
    :timer.sleep(100)
  end

  describe "shared connection" do
    it "- reopen consumers", _context do
      {:ok, c1} = TestConsumer1.start_link()
      {:ok, c2} = TestConsumer2.start_link()

      # only one connection opend
      assert Tackle.Connection.get_all() |> Enum.count() == 1

      verify_consumer_functionality()

      # kill consumers
      Process.unlink(c1)
      Process.unlink(c2)
      Process.exit(c1, :kill)
      Process.exit(c2, :kill)

      # kill connection process
      assert Tackle.Connection.get_all() |> Enum.count() == 1
      old_pid = get_all_connections()
      old_pid |> Process.exit(:kill)

      # restart consumers
      {:ok, _} = TestConsumer1.start_link()
      {:ok, _} = TestConsumer2.start_link()

      # new connection process?
      assert Tackle.Connection.get_all() |> Enum.count() == 1
      new_pid = get_all_connections()
      assert old_pid != new_pid

      verify_consumer_functionality()
    end

    def verify_consumer_functionality do
      Tackle.publish(self() |> inspect, @publish_options_1)
      Tackle.publish(self() |> inspect, @publish_options_2)

      response = rcv() <> rcv()
      assert String.contains?(response, "consumer_1")
      assert String.contains?(response, "consumer_2")
    end

    def get_all_connections do
      Tackle.Connection.get_all() |> Keyword.get(:single_connection) |> Map.get(:pid)
    end

    def rcv do
      receive do
        msg -> msg
      end
    end
  end
end
