defmodule Tackle.BrokenConsumerTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages-broken",
      service: "broken-service",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service")
      throw("Exception thrown!")
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages-broken",
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

      assert MessageTrace.content("broken-service") == "Hi!Hi!Hi!Hi!"
    end
  end
end
