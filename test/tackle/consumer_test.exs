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

  describe "format_status/2" do
    test "hides the connection url's credentials without touching the real state" do
      raw_url = "amqp://produser:sup3rSecret@rabbitmq:5672/prod"

      state = %{
        url: raw_url,
        channel: :fake_channel,
        has_dead_letter?: true,
        delay_queue: "delay_queue",
        dead_queue: "dead_queue",
        retry_limit: 10,
        consumer_tag: "tag"
      }

      [{:data, [{'State', sanitized_state}]}] =
        ConsumerExample.format_status(:normal, [[], state])

      refute inspect(sanitized_state) =~ "sup3rSecret"
      refute inspect(sanitized_state) =~ ~r/amqp:\/\/[^\/]*:[^\/]*@/
      assert sanitized_state.url == "amqp://rabbitmq:5672/prod"

      # the actual runtime state (read by reconnect/retry logic) is untouched
      assert state.url == raw_url
    end
  end
end
