defmodule Tackle do
  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    children = [
      Tackle.Connection
    ]

    opts = [strategy: :one_for_one, name: Tackle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def publish(message, options) when is_binary(message) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]

    Logger.debug("Connecting to '#{Tackle.DebugHelper.safe_uri(url)}'")
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    Logger.debug("Declaring an exchange '#{exchange}'")
    Tackle.Exchange.create_remote_exchange(channel, exchange)

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
