defmodule Tackle.Channel do
  use AMQP
  require Logger

  @prefetch_count 1

  @spec create(AMQP.Connection.t(), any) :: AMQP.Channel.t()
  def create(connection, prefetch_count \\ @prefetch_count) do
    {:ok, channel} = Channel.open(connection)

    :ok = Basic.qos(channel, prefetch_count: prefetch_count)

    channel
  end
end
