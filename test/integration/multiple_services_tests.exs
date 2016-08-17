defmodule Tackle.MultipleServicesTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule ServiceA do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "a",
      service: "serviceA",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      IO.puts "ServiceA: received '#{message}'"

      message |> MessageTrace.save("serviceA")
    end
  end

  # broken service
  defmodule ServiceB do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "a",
      service: "serviceB",
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      IO.puts "ServiceB: received '#{message}'"

      message |> MessageTrace.save("serviceB")

      raise "broken"
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "a"
  }

  setup do
    Support.create_exchange("test-exchange")

    {:ok, serviceA} = ServiceA.start_link
    {:ok, serviceB} = ServiceB.start_link

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
end
