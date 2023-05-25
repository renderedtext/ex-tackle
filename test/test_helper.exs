defmodule Support do
  def create_exchange(exchange_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://rabbitmq:5672")
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.direct(channel, exchange_name, durable: true)

    AMQP.Connection.close(connection)
  end

  def queue_status(queue_name) do
    {:ok, connection} = AMQP.Connection.open("amqp://rabbitmq:5672")
    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, status} = AMQP.Queue.status(channel, queue_name)

    AMQP.Connection.close(connection)

    status
  end

  def purge_queue(queue_name, set_ttl \\ false) do
    {:ok, connection} = AMQP.Connection.open("amqp://rabbitmq:5672")
    {:ok, channel} = AMQP.Channel.open(connection)

    if set_ttl do
      AMQP.Queue.declare(channel, queue_name,
        durable: true,
        arguments: [
          {"x-message-ttl", :long, 604_800_000}
        ]
      )
    else
      AMQP.Queue.declare(channel, queue_name, durable: true)
    end

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

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter], capture_log: true)
ExUnit.start()
