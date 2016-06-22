defmodule Tackle.Channel do
  use AMQP

  def create(amqp_url) do
    {:ok, conn}    = Connection.open(amqp_url)
    {:ok, channel} = Channel.open(conn)

    # Limit unacknowledged messages to 10
    Basic.qos(channel, prefetch_count: 10)

    channel
  end

end
