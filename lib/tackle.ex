defmodule Tackle do
  require Logger
  use AMQP

  def publish(message, options) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]

    Logger.info "Connecting to '#{url}'"
    channel = Tackle.Channel.create(url)

    Logger.info "Declaring an exchange '#{exchange}'"
    Exchange.direct(channel, exchange, durable: true)

    AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)
  end

end
