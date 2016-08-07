defmodule TackleTest do
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
      {:ok, file} = File.open "/tmp/messages", [:write]

      IO.binwrite(file, message)

      File.close(file)
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages",
  }

  describe "tackle communication" do
    it "receives a published message on the exchange" do
      {:ok, consumer} = TestConsumer.start_link

      :timer.sleep(1000)

      File.rm("/tmp/messages")

      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(1000)

      messages = File.read!("/tmp/messages")

      assert String.contains?(messages, "Hi!")
    end
  end

  @broken_publish_options %{
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "broken-messages",
  }

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "broken-messages",
      service: "broker-service",
      retry_limit: 3,
      retry_delay: 1

    def handle_message(message) do
      IO.puts "Here!"

      {:ok, file} = File.open "/tmp/messages", [:append]
      IO.binwrite(file, message)
      File.close(file)

      :foo + 1 # raises an exception
    end
  end

  describe "retry to process message" do
    it "retries to consume the message" do
      {:ok, consumer} = BrokenConsumer.start_link

      File.rm("/tmp/messages")

      Tackle.publish("Hi!", @broken_publish_options)

      :timer.sleep(5000)

      GenServer.stop(consumer)

      assert File.read!("/tmp/messages") == "Hi!Hi!Hi!Hi!"
    end
  end

end
