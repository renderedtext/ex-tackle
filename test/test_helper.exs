defmodule Support do
  def create_exchange(exchange_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.direct(channel, exchange_name, durable: true)

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
