defmodule Tackle.ListenerTest do
  use ExSpec

  defmodule TestConsumer do
    require Logger

    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "test-messages",
      service: "ex-tackle.test-service"

    def handle_message(_message) do
      Logger.debug("here")
    end
  end

  setup do
    reset_test_exchanges_and_queues()

    on_exit(fn ->
      reset_test_exchanges_and_queues()
    end)
  end

  describe "consumer creation" do
    it "connects to amqp server without errors" do
      {response, _consumer} = TestConsumer.start_link()

      assert response == :ok
    end

    it "creates a queue on the amqp server" do
      {_response, _consumer} = TestConsumer.start_link()

      :timer.sleep(1000)

      {response, 0} = System.cmd("rabbitmqctl", ["list_queues"])

      assert String.contains?(response, "ex-tackle.test-service.test-messages")
      assert String.contains?(response, "ex-tackle.test-service.test-messages.delay.10")
      assert String.contains?(response, "ex-tackle.test-service.test-messages.dead")
    end

    it "creates an exchange on the amqp server" do
      {_response, _consumer} = TestConsumer.start_link()

      :timer.sleep(1000)

      {response, 0} = System.cmd("rabbitmqctl", ["list_exchanges"])

      assert String.contains?(response, "ex-tackle.test-service.test-messages")
    end
  end

  defp reset_test_exchanges_and_queues do
    Support.delete_all_queues("ex-tackle.test-service.test-messages", 10)

    Support.delete_exchange("ex-tackle.test-service.test-messages")
    Support.delete_exchange("ex-tackle.test-exchange")
  end
end
