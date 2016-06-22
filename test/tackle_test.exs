defmodule TackleTest do
  use ExSpec

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      queue: "test-consumer-queue"

    def handle_message(message) do
      IO.puts "here"
    end
  end

  describe "consumer creation" do
    it "connects to amqp server" do
      {response, consumer} = TestConsumer.start_link

      assert response == :ok
    end
  end

end
