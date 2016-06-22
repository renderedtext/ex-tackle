defmodule Tackle.Channel do
  use AMQP

  def create(connection) do
    {:ok, channel} = Channel.open(connection)

    # Limit unacknowledged messages to 10
    Basic.qos(channel, prefetch_count: 10)

    channel
  end

end
