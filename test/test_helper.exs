defmodule Support do
  def create_exchange(exchange_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.direct(channel, exchange_name, durable: true)

    AMQP.Connection.close(connection)
  end

  def delete_exchange(exchange_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    :ok = AMQP.Exchange.delete(channel, exchange_name)

    AMQP.Connection.close(connection)
  end

  def queue_status(queue_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, status} = AMQP.Queue.status(channel, queue_name)

    AMQP.Connection.close(connection)

    status
  end

  def purge_queue(queue_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end

  def delete_queue(queue_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, _} = AMQP.Queue.delete(channel, queue_name)

    AMQP.Connection.close(connection)
  end

  def delete_all_queues(queue_name, delay \\ 1) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.delete(channel, queue_name)
    AMQP.Queue.delete(channel, queue_name <> ".dead")
    AMQP.Queue.delete(channel, queue_name <> ".delay.#{delay}")

    AMQP.Connection.close(connection)
  end

  defmodule MessageTrace do
    # we should reimplement this with something nicer
    # like an in memory queue

    def save(message, trace_name) do
      File.write("/tmp/#{trace_name}", message, [:append])
    end

    def clear(trace_name) do
      File.rm_rf("/tmp/#{trace_name}")
    end

    def content(trace_name) do
      File.read!("/tmp/#{trace_name}")
    end
  end
end

ExUnit.start(trace: false)
