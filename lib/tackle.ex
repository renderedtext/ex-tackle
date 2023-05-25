defmodule Tackle do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      Tackle.Connection
    ]

    opts = [strategy: :one_for_one, name: Tackle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def publish(message, options) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]
    exchange_opts = options[:exchange_opts] || []

    {_exchange_type, exchange_name} =
      exchange
      |> Tackle.Util.parse_exchange()

    Logger.debug("Connecting to '#{url}'")
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    try do
      Tackle.Exchange.create(channel, exchange, exchange_opts)
      Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
    after
      AMQP.Channel.close(channel)
      AMQP.Connection.close(connection)
    end
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
