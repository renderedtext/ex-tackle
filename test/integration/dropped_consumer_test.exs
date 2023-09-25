defmodule Tackle.DroppedConsumerTest do
  use ExUnit.Case, async: false

  alias Support

  defmodule DroppedConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-key",
      service: "dropped-service"

    def handle_message(_message) do
      :noop
    end
  end

  describe "dropped consumer" do
    test "should be remove from the server" do
      {:ok, pid} = DroppedConsumer.start_link()
      :timer.sleep(100)

      assert Support.consumer_count("dropped-service.test-key") == 1

      GenServer.stop(pid, :normal)
      :timer.sleep(100)

      assert Support.consumer_count("dropped-service.test-key") == 0
    end
  end
end
