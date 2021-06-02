defmodule Tackle.BrokenConsumerTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  import ExUnit.CaptureIO

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "broken-service",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("broken-service")

      capture_io(fn ->
        # exception
        :a + 1
      end)
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages"
  }

  setup do
    Support.purge_queue("broken-service.test-messages")

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
end
