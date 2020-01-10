defmodule Tackle.DeadQueueTest do
  use ExSpec

  alias Support

  defmodule DeadConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "dead-service",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      :a + 1 # exception
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages",
  }

  @dead_queue "dead-service.test-messages.dead"

  setup do
    Support.purge_queue("dead-service.test-messages")
    Support.purge_queue(@dead_queue, true)

    {:ok, _} = DeadConsumer.start_link

    :ok
  end

  describe "broken consumer" do
    it "puts the messages o dead queue after failures" do
      assert Support.queue_status(@dead_queue).message_count == 0

      Tackle.publish("Hi!", @publish_options)
      :timer.sleep(5000)

      assert Support.queue_status(@dead_queue).message_count == 1
    end
  end
end
