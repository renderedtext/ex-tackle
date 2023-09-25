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

  defmodule TestMulticonsumerWithoutDeadLetter do
    require Logger

    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "TestMulticonsumerWithoutDeadLetterService",
      routes: [
        {"TestMulticonsumerWithoutDeadLetterExchange", "test-messages", :handler}
      ],
      dead_letter_queue: false

    def handler(_message) do
      Logger.info("Handled!")
    end
  end

  defmodule TestConsumerWithoutDeadLetter do
    require Logger

    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "TestConsumerWithoutDeadLetterExchange",
      routing_key: "test-messages",
      service: "TestConsumerWithoutDeadLetterService",
      dead_letter_queue: false

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

  describe "TestConsumerWithoutDeadLetter" do
    test "creates a queue without dead letters if configured to do so", %{channel: channel} do
      {response, _} = TestConsumerWithoutDeadLetter.start_link()

      assert response == :ok

      {:ok, %{consumer_count: 1}} =
        AMQP.Queue.declare(channel, "TestConsumerWithoutDeadLetterService.test-messages",
          passive: true
        )

      catch_exit(
        AMQP.Queue.declare(channel, "TestConsumerWithoutDeadLetterService.test-messages.delay.10",
          passive: true
        )
      )

      catch_exit(
        AMQP.Queue.declare(channel, "TestConsumerWithoutDeadLetterService.test-messages.dead",
          passive: true
        )
      )
    end
  end

  describe "TestMulticonsumerWithoutDeadLetter" do
    test "creates a queue without dead letters if configured to do so", %{channel: channel} do
      {response, _} = TestMulticonsumerWithoutDeadLetter.start_link()

      assert response == :ok

      {:ok, %{consumer_count: 1}} =
        AMQP.Queue.declare(channel, "TestMulticonsumerWithoutDeadLetterService.test-messages",
          passive: true
        )

      catch_exit(
        AMQP.Queue.declare(
          channel,
          "TestMulticonsumerWithoutDeadLetterService.test-messages.delay.10",
          passive: true
        )
      )

      catch_exit(
        AMQP.Queue.declare(
          channel,
          "TestMulticonsumerWithoutDeadLetterService.test-messages.dead",
          passive: true
        )
      )
    end
  end
end
