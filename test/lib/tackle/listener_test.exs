defmodule Tackle.ListenerTest do
  use ExUnit.Case, async: false

  defmodule TestConsumer do
    require Logger

    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "test-service"

    def handle_message(_) do
      Logger.info("Received message")
    end
  end

  setup do
    {:ok, conn} = AMQP.Connection.open("amqp://rabbitmq:5672")
    {:ok, channel} = AMQP.Channel.open(conn)

    [
      conn: conn,
      channel: channel
    ]
  end

  describe "consumer creation" do
    test "creates a queue on the amqp server", %{channel: channel} do
      {response, _} = TestConsumer.start_link()

      assert response == :ok

      {:ok, %{consumer_count: 1}} = AMQP.Queue.status(channel, "test-service.test-messages")

      {:ok, _} = AMQP.Queue.status(channel, "test-service.test-messages.delay.10")

      {:ok, _} = AMQP.Queue.status(channel, "test-service.test-messages.dead")
    end
  end
end
