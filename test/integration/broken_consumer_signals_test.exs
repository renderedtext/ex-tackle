defmodule Tackle.BrokenConsumerSignalsTest do
  use ExUnit.Case, async: false

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "broken-service-signal",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service-signal")

      Process.exit(self(), {:foo, message})
    end
  end

  @publish_options %{
    url: "amqp://rabbitmq:5672",
    exchange: "test-exchange",
    routing_key: "test-messages"
  }

  setup do
    Support.purge_queue("broken-service-signal.test-messages")

    MessageTrace.clear("broken-service-signal")

    {:ok, _} = BrokenConsumer.start_link()

    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    test "receives the message multiple times" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("broken-service-signal") == "Hi!Hi!Hi!Hi!"
    end
  end
end
