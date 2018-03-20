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
    @test_store_name :test_store

    def reset, do: :ets.delete(@test_store_name)

    def setup do
      :ets.new(@test_store_name, [:set, :public, :named_table])
      :ok
    end

    def save(message, trace_name) do
      stored = :ets.lookup(@test_store_name, trace_name)
      case List.first(stored) do
        nil -> :ets.insert(@test_store_name, {trace_name, message})
        {_trace_name, value} -> :ets.insert(@test_store_name, {trace_name, Enum.join([value, message], "")})
      end
    end

    def clear(trace_name) do
      :ets.delete_object(@test_store_name, trace_name)
    end

    def content(trace_name) do
      stored_value = :ets.lookup(@test_store_name, trace_name)
      case List.first(stored_value) do
        {_trace_name, value} -> value
        _ -> nil
      end
    end
  end

end

ExUnit.start([trace: true])
