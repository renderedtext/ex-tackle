defmodule Tackle.ListenerTest do
  use ExSpec

  setup do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.direct(channel, "test-exchange", durable: true)

    AMQP.Connection.close(connection)
  end

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "test-service"

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

      assert String.contains?(response, "test-service.test-messages")
      assert String.contains?(response, "test-service.test-messages.delay.10")
      assert String.contains?(response, "test-service.test-messages.dead")
    end

    it "creates an exchange on the amqp server" do
      {response, consumer} = TestConsumer.start_link

      :timer.sleep(1000)

      {response, 0} = System.cmd "sudo", ["rabbitmqctl", "list_exchanges"]

      assert String.contains?(response, "test-service.test-messages")
    end
  end

end
