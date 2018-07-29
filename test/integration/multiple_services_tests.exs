defmodule Tackle.MultipleServicesTest do
  use ExSpec

  alias Support.MessageTrace

  defmodule ServiceA do
    require Logger

    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "a",
      service: "ex-tackle.serviceA",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      Logger.info("ServiceA: received '#{message}'")

      message |> MessageTrace.save("serviceA")
    end
  end

  # broken service
  defmodule ServiceB do
    require Logger

    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "a",
      service: "ex-tackle.serviceB",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      Logger.info("ServiceB: received '#{message}'")

      message |> MessageTrace.save("serviceB")

      raise "broken"
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "ex-tackle.test-exchange",
    routing_key: "a"
  }

  setup do
    reset_test_exchanges_and_queues()

    on_exit(fn ->
      reset_test_exchanges_and_queues()
    end)

    {:ok, _serviceA} = ServiceA.start_link()
    {:ok, _serviceB} = ServiceB.start_link()

    MessageTrace.clear("serviceA")
    MessageTrace.clear("serviceB")

    :ok
  end

  describe "multiple services listening on the same exchange with the same routing_key" do
    it "sends message to both services" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("serviceA") |> String.contains?("Hi!")
      assert MessageTrace.content("serviceB") |> String.contains?("Hi!")
    end

    it "sends the message only once to the healthy service" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("serviceA") == "Hi!"
    end

    it "sends the message multiple times to the broken service" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(5000)

      assert MessageTrace.content("serviceB") == "Hi!Hi!Hi!Hi!"
    end
  end

  defp reset_test_exchanges_and_queues do
    Support.delete_all_queues("ex-tackle.serviceA.a")
    Support.delete_all_queues("ex-tackle.serviceB.a")

    Support.delete_exchange("ex-tackle.serviceA.a")
    Support.delete_exchange("ex-tackle.serviceB.a")
    Support.delete_exchange("ex-tackle.test-exchange")
  end
end
