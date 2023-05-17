defmodule Tackle.ConnectionErrorsTest do
  use ExUnit.Case

  alias Support
  alias Support.MessageTrace

  defmodule AckFailConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "connection-errors-service",
      connection_id: :ack_fail,
      retry_limit: 0

    def handle_message(message) do
      message |> MessageTrace.save("connection-errors")

      Tackle.Connection.get_all()
      |> Keyword.get(:ack_fail)
      |> Map.get(:pid)
      |> Process.exit(:kill)

      :timer.sleep(1000)

      :ok
    end
  end

  defmodule DelayFailConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "connection-errors-service",
      connection_id: :delay_fail,
      retry_delay: 1,
      retry_limit: 3

    def handle_message(message) do
      message |> MessageTrace.save("connection-errors")

      Tackle.Connection.get_all()
      |> Keyword.get(:delay_fail)
      |> Map.get(:pid)
      |> Process.exit(:kill)

      :timer.sleep(1000)

      # exception
      :a + 1
    end
  end

  defmodule DeadFailConsumer do
    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "connection-errors-service",
      connection_id: :dead_fail,
      retry_limit: 0

    def handle_message(message) do
      message |> MessageTrace.save("connection-errors")

      Tackle.Connection.get_all()
      |> Keyword.get(:dead_fail)
      |> Map.get(:pid)
      |> Process.exit(:kill)

      :timer.sleep(1000)

      # exception
      :a + 1
    end
  end

  @publish_options %{
    url: "amqp://rabbitmq:5672",
    exchange: "test-exchange",
    routing_key: "test-messages"
  }

  setup do
    MessageTrace.clear("connection-errors")

    :ok
  end

  test "consumer dies if connection is lost before ack is sent" do
    task =
      Task.async(fn ->
        {:ok, pid} = AckFailConsumer.start_link()
        pid
      end)

    pid = Task.await(task)

    Tackle.publish("Hi!", @publish_options)

    :timer.sleep(2000)

    assert MessageTrace.content("connection-errors") == "Hi!"

    assert Process.alive?(pid) == false
  end

  test "consumer dies if connection is lost while pushing message to delay queue" do
    task =
      Task.async(fn ->
        {:ok, pid} = DelayFailConsumer.start_link()
        pid
      end)

    pid = Task.await(task)

    Tackle.publish("Hi!", @publish_options)

    :timer.sleep(2000)

    assert MessageTrace.content("connection-errors") == "Hi!"

    assert Process.alive?(pid) == false
  end

  test "consumer dies if connection is lost while pushing message to dead queue" do
    task =
      Task.async(fn ->
        {:ok, pid} = DeadFailConsumer.start_link()
        pid
      end)

    pid = Task.await(task)

    Tackle.publish("Hi!", @publish_options)

    :timer.sleep(2000)

    assert MessageTrace.content("connection-errors") == "Hi!"

    assert Process.alive?(pid) == false
  end
end
