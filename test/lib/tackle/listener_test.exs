defmodule Tackle.ListenerTest do
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
    it "connects to amqp server without errors" do
      {response, consumer} = TestConsumer.start_link

      assert response == :ok
    end

    it "creates a queue on the amqp server" do
      {response, consumer} = TestConsumer.start_link

      :timer.sleep(1000)

      {response, 0} = System.cmd "sudo", ["rabbitmqctl", "list_queues"]

      assert String.contains?(response, "test-consumer-queue")
      assert String.contains?(response, "test-consumer-queue_dead_letters")
    end

    it "creates an exchange on the amqp server" do
      {response, consumer} = TestConsumer.start_link

      :timer.sleep(1000)

      {response, 0} = System.cmd "sudo", ["rabbitmqctl", "list_exchanges"]

      assert String.contains?(response, "test-exchange")
    end
  end

end
