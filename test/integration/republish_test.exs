defmodule Tackle.RepublishTest do
  use ExUnit.Case, async: false

  alias Support
  alias Support.MessageTrace

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "RepublishExchange",
      routing_key: "test-messages",
      service: "RepublishService",
      retry_delay: 1,
      retry_limit: 1,
      queue: "RepublishQueue"

    def handle_message(_) do
      # exception
      raise "oops"
    end
  end

  defmodule FixedConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "RepublishExchange",
      routing_key: "test-messages",
      service: "RepublishService",
      retry_delay: 1,
      retry_limit: 3,
      queue: "RepublishQueue"

    def handle_message(message) do
      Logger.info("FixedConsumer: received '#{message}'")
      message |> MessageTrace.save("fixed-service")
    end
  end

  @publish_options %{
    url: "amqp://rabbitmq:5672",
    exchange: "RepublishExchange",
    routing_key: "test-messages"
  }

  @queue "RepublishQueue"
  @dead_queue "RepublishQueue.dead"

  setup do
    Support.create_exchange("RepublishExchange")

    Support.purge_queue(@queue)
    Support.purge_queue(@dead_queue, true)

    :timer.sleep(1000)
  end

  describe "republishing" do
    setup do
      #
      # consume with a broken consumer
      #

      Support.purge_queue(@dead_queue, true)
      :timer.sleep(1000)
      {:ok, broken_consumer} = BrokenConsumer.start_link()

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
      {:ok, fixed_consumer} = FixedConsumer.start_link()
      :timer.sleep(1000)

      Tackle.republish(%{
        url: "amqp://rabbitmq:5672",
        queue: @dead_queue,
        exchange: "RepublishExchange",
        routing_key: "test-messages",
        count: 2
      })

      :timer.sleep(1000)

      GenServer.stop(fixed_consumer)
    end

    test "consumes only two messages" do
      assert MessageTrace.content("fixed-service") == "Hi there!"
    end

    test "leaves the remaining messages in the dead qeueue" do
      assert Support.queue_status(@dead_queue).message_count == 1
    end
  end
end
