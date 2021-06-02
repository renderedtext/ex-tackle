defmodule Tackle.RepublishTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "republish-service",
      retry_delay: 1,
      retry_limit: 1

    def handle_message(_) do
      # exception
      :a + 1
    end
  end

  defmodule FixedConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "republish-service",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("fixed-service")
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages"
  }

  @dead_queue "republish-service.test-messages.dead"

  setup do
    Support.create_exchange("test-exchange")

    Support.purge_queue("republish-service.test-messages")
  end

  describe "republishing" do
    setup do
      #
      # consume with a broken consumer
      #

      {:ok, broken_consumer} = BrokenConsumer.start_link()
      :timer.sleep(1000)

      Support.purge_queue(@dead_queue, true)
      assert Support.queue_status(@dead_queue).message_count == 0

      Tackle.publish("Hi ", @publish_options)
      :timer.sleep(200)

      Tackle.publish("there!", @publish_options)
      :timer.sleep(200)

      Tackle.publish(" noooo!!!", @publish_options)
      :timer.sleep(5000)

      #
      # stop the broken consumer
      #

      GenServer.stop(broken_consumer)
      assert Support.queue_status(@dead_queue).message_count == 3
      :timer.sleep(1000)

      #
      # start another consumer that fixes the issue
      #

      MessageTrace.clear("fixed-service")
      {:ok, _} = FixedConsumer.start_link()
      :timer.sleep(1000)

      Tackle.republish(%{
        url: "amqp://localhost",
        queue: @dead_queue,
        exchange: "test-exchange",
        routing_key: "test-messages",
        count: 2
      })

      :timer.sleep(2000)
    end

    it "consumes only two messages" do
      assert MessageTrace.content("fixed-service") == "Hi there!"
    end

    it "leaves the remaining messages in the dead qeueue" do
      assert Support.queue_status(@dead_queue).message_count == 1
    end
  end
end
