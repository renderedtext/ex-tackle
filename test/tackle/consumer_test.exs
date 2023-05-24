defmodule Tackle.ConsumerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  defmodule ConsumerExample do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      service: "example_service",
      exchange: "some_exchange",
      routing_key: "some.routing.key",
      queue_name: :dynamic

    def handle_message(message) do
      send(:checker, message)
    end
  end

  defmodule TopicConsumerExample do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      service: "example_service",
      exchange: {:topic, "topic_exchange"},
      routing_key: "some.routing.key"

    def handle_message(message) do
      send(:checker, message)
    end
  end

  describe "Consumer with dynamic queue name" do
    test "every queue subscribed tto a routing key receives an event" do
      Process.register(self(), :checker)

      ConsumerExample.start_link(process_name: {:global, make_ref()})
      ConsumerExample.start_link(process_name: {:global, make_ref()})

      Tackle.publish("HELLO WORLD!",
        url: "amqp://rabbitmq:5672",
        exchange: "some_exchange",
        routing_key: "some.routing.key"
      )

      assert_receive "HELLO WORLD!", 1000
      assert_receive "HELLO WORLD!", 1000
      refute_receive "HELLO WORLD!", 1000
    end
  end
end
