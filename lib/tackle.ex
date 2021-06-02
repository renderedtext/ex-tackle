defmodule Tackle do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Tackle.Connection, [])
    ]

    opts = [strategy: :one_for_one, name: Tackle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def publish(message, options) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]

    Logger.debug("Connecting to '#{url}'")
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    Logger.debug("Declaring an exchange '#{exchange}'")
    Tackle.Exchange.create(channel, exchange)

    Tackle.Exchange.publish(channel, exchange, message, routing_key)

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
