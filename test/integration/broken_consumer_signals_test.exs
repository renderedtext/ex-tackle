defmodule Tackle.BrokenConsumerSignalsTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages-signal",
      service: "broken-service-signal",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service-signal")

      Process.exit(self(), {:foo, message})
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages-signal",
  }

  setup do
    MessageTrace.setup()
    BrokenConsumer.start_link
    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    it "receives the message multiple times" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("broken-service-signal") == "Hi!Hi!Hi!Hi!"
    end
  end
end
