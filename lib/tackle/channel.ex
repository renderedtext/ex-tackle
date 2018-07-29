defmodule Tackle.Channel do
  use AMQP
  require Logger

  @prefetch_count 1

  def create(connection) do
    create(connection, @prefetch_count)
  end

  def create(connection, nil) do
    create(connection, @prefetch_count)
  end

  def create(connection, prefetch_count) do
    {:ok, channel} = Channel.open(connection)

    Basic.qos(channel, prefetch_count: prefetch_count)

    channel
  end
end
