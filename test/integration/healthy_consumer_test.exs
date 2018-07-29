defmodule Tackle.HealthyConsumerTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "health",
      service: "ex-tackle.healthy-service"

    def handle_message(message) do
      message |> MessageTrace.save("healthy-service")
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "ex-tackle.test-exchange",
    routing_key: "health"
  }

  setup do
    reset_test_exchanges_and_queues()

    on_exit(fn ->
      reset_test_exchanges_and_queues()
    end)

    MessageTrace.clear("healthy-service")

    {:ok, _} = TestConsumer.start_link()

    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    it "receives a published message on the exchange" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(1000)

      assert MessageTrace.content("healthy-service") == "Hi!"
    end
  end

  defp reset_test_exchanges_and_queues do
    Support.delete_all_queues("ex-tackle.healthy-service.health", 10)

    Support.delete_exchange("ex-tackle.healthy-service.health")
    Support.delete_exchange("ex-tackle.test-exchange")
  end
end
