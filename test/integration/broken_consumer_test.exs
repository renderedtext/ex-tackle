defmodule Tackle.BrokenConsumerTest do
  use ExSpec

  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "test-messages",
      service: "ex-tackle.broken-service",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service")

      # exception without warning
      Code.eval_quoted(quote do: :a + 1)
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "ex-tackle.test-exchange",
    routing_key: "test-messages"
  }

  setup do
    reset_test_exchanges_and_queues()

    on_exit(fn ->
      reset_test_exchanges_and_queues()
    end)

    MessageTrace.clear("broken-service")

    {:ok, _} = BrokenConsumer.start_link()

    :timer.sleep(1000)
  end

  describe "healthy consumer" do
    it "receives the message multiple times" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("broken-service") == "Hi!Hi!Hi!Hi!"
    end
  end

  defp reset_test_exchanges_and_queues do
    Support.delete_all_queues("ex-tackle.broken-service.test-messages")

    Support.delete_exchange("ex-tackle.broken-service.test-messages")
    Support.delete_exchange("ex-tackle.test-exchange")
  end
end
