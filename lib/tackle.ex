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

    Logger.info "Connecting to '#{url}'"
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    (0..count-1) |> Enum.each(fn(index) ->
      IO.write "(#{index}) Fetching message... "

      case AMQP.Basic.get(channel, queue) do
        {:empty, _} ->
          IO.puts "no more messages"

        {:ok, message, %{delivery_tag: tag}} ->
          AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)
          AMQP.Basic.ack(channel, tag)
          IO.puts "republished"
      end
    end)

    AMQP.Connection.close(connection)
  end

end
