defmodule Support do
  def create_exchange(exchange_name) do
    execute(fn channel ->
      Tackle.Exchange.create(channel, exchange_name)
    end)
  end

  def delete_exchange(exchange_name) do
    execute(fn channel ->
      :ok = AMQP.Exchange.delete(channel, exchange_name)
    end)
  end

  def queue_status(queue_name) do
    {:ok, status} =
      execute(fn channel ->
        AMQP.Queue.status(channel, queue_name)
      end)

    status
  end

  def purge_queue(queue_name) do
    execute(fn channel ->
      AMQP.Queue.purge(channel, queue_name)
    end)
  end

  def delete_queue(queue_name) do
    execute(fn channel ->
      {:ok, _} = AMQP.Queue.delete(channel, queue_name)
    end)
  end

  def delete_all_queues(queue_name, delay \\ 1) do
    execute(fn channel ->
      AMQP.Queue.delete(channel, queue_name)
      AMQP.Queue.delete(channel, queue_name <> ".dead")
      AMQP.Queue.delete(channel, queue_name <> ".delay.#{delay}")
    end)
  end

  defp execute(fun) when is_function(fun, 1) do
    {:ok, connection} = AMQP.Connection.open("amqp://localhost")
    {:ok, channel} = AMQP.Channel.open(connection)
    result = fun.(channel)
    AMQP.Connection.close(connection)
    result
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
