defmodule TackleTest do
  use ExSpec

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      queue: "test-consumer-queue"

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
      {response, consumer} = TestConsumer.start_link

      :timer.sleep(2000)

      Tackle.publish("Hi!", @publish_options)

      :timer.sleep(2000)

      messages = File.read!("/tmp/messages")

      assert String.contains?(messages, "Hi!")
    end
  end

end
