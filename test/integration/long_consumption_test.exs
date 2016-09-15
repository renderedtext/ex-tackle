defmodule Tackle.LongConsumptionTest do
  use ExSpec

  alias Support
  alias Support.MessageTrace

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "health",
      service: "slow-service"

    def handle_message(message) do
      (1..10) |> Enum.each fn(index) ->
        IO.puts "HERE #{index}"
        :timer.sleep(1000)
      end

      message |> MessageTrace.save("slow-service")
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "health",
  }

  setup do
    MessageTrace.clear("slow-service")

    {:ok, _} = TestConsumer.start_link

    :timer.sleep(1000)
  end

  describe "slow consumer" do
    it "receives a published message on the exchange" do
      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(11000)

      assert MessageTrace.content("slow-service") == "Hi!"
    end
  end
end
