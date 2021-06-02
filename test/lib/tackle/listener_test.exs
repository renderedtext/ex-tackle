defmodule Tackle.ListenerTest do
  use ExSpec

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "test-service"

    def handle_message(_) do
      IO.puts("here")
    end
  end

  describe "consumer creation" do
    it "connects to amqp server without errors" do
      {response, _} = TestConsumer.start_link()

      assert response == :ok
    end

    it "creates a queue on the amqp server" do
      {_, _} = TestConsumer.start_link()

      :timer.sleep(1000)

      {response, 0} =
        case System.get_env("DOCKER_RABBITMQ") do
          "true" ->
            System.cmd("docker", [
              "exec",
              System.get_env("DOCKER_RABBITMQ_CONTAINER_NAME"),
              "rabbitmqctl",
              "list_queues"
            ])

          _ ->
            System.cmd("sudo", ["rabbitmqctl", "list_queues"])
        end

      assert String.contains?(response, "test-service.test-messages")
      assert String.contains?(response, "test-service.test-messages.delay.10")
      assert String.contains?(response, "test-service.test-messages.dead")
    end

    it "creates an exchange on the amqp server" do
      {_, _} = TestConsumer.start_link()

      :timer.sleep(1000)

      {response, 0} =
        case System.get_env("DOCKER_RABBITMQ") do
          "true" ->
            System.cmd("docker", [
              "exec",
              System.get_env("DOCKER_RABBITMQ_CONTAINER_NAME"),
              "rabbitmqctl",
              "list_queues"
            ])

          _ ->
            System.cmd("sudo", ["rabbitmqctl", "list_queues"])
        end

      assert String.contains?(response, "test-service.test-messages")
    end
  end
end
