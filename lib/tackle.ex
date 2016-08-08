defmodule Tackle do
  require Logger

  def publish(message, options) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]

    Logger.info "Connecting to '#{url}'"
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    Logger.info "Declaring an exchange '#{exchange}'"
    AMQP.Exchange.direct(channel, exchange, durable: true)

    AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)

    AMQP.Connection.close(connection)
  end

  def republish(message, options) do
    url = options[:url]
    queue = options[:exchange]
    exchange = options[:exchange]
    routing_key = options[:routing_key]

    # do something
  end

end
