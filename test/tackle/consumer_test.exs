defmodule Tackle.ConsumerTest do
  use ExUnit.Case, async: false

  defmodule ConsumerExample do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      service: "ConsumerTestService",
      exchange: "ConsumerTestExchange",
      routing_key: "some.routing.key",
      queue: :dynamic,
      queue_opts: [
        auto_delete: true,
        exclusive: true
      ]

    def handle_message(message) do
      send(:checker, message)
    end
  end

  describe "Consumer with dynamic queue name" do
    test "every queue subscribed to a routing key receives an event" do
      Process.register(self(), :checker)

      ConsumerExample.start_link(process_name: {:global, make_ref()})
      ConsumerExample.start_link(process_name: {:global, make_ref()})

      Tackle.publish("HELLO WORLD!",
        url: "amqp://rabbitmq:5672",
        exchange: "ConsumerTestExchange",
        routing_key: "some.routing.key"
      )

      assert_receive "HELLO WORLD!", 1000
      assert_receive "HELLO WORLD!", 1000
      refute_receive "HELLO WORLD!", 1000
    end
  end
end
