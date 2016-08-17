defmodule Tackle.HealthyConsumerTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "health",
      service: "healthy-service"

    def handle_message(message) do
      message |> MessageTrace.save("healthy-service")
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "health",
  }

  setup do
    Support.create_exchange("test-exchange")

    MessageTrace.clear("healthy-service")

    {:ok, _} = TestConsumer.start_link

    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    it "receives a published message on the exchange" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(1000)

      assert MessageTrace.content("healthy-service") == "Hi!"
    end
  end
end
