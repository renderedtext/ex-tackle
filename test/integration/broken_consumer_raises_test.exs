defmodule Tackle.BrokenConsumerRaisesTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "broken-service-raise",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service-raise")

      raise "Raised!"
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages"
  }

  setup do
    Support.purge_queue("broken-service-raise.test-messages")

    MessageTrace.clear("broken-service-raise")

    {:ok, _} = BrokenConsumer.start_link()

    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    it "receives the message multiple times" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("broken-service-raise") == "Hi!Hi!Hi!Hi!"
    end
  end
end
