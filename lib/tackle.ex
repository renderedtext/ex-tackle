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

  def republish(options) do
    url = options[:url]
    queue = options[:queue]
    exchange = options[:exchange]
    routing_key = options[:routing_key]
    count = options[:count] || 1

    Tackle.Republisher.republish(url, queue, exchange, routing_key, count)
  end

end
