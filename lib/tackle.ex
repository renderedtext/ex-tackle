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
    connection_id = options[:connection_id] || :default

    {_exchange_type, exchange_name} =
      exchange
      |> Tackle.Util.parse_exchange()

    {:ok, connection} = Tackle.Connection.open(connection_id, url)
    channel = Tackle.Channel.create(connection)

    try do
      Tackle.Exchange.create(channel, exchange, exchange_opts)
      Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
    after
      Tackle.Util.cleanup(connection_id, connection, channel)
    end
  end

  def republish(options) do
    url = options[:url]
    queue = options[:queue]
    exchange_name = options[:exchange]
    routing_key = options[:routing_key]
    count = options[:count] || 1
    connection_id = options[:connection_id] || :default

    {:ok, connection} = Tackle.Connection.open(connection_id, url)
    channel = Tackle.Channel.create(connection)

    try do
      Tackle.Republisher.republish(url, queue, exchange_name, routing_key, count)
    after
      Tackle.Util.cleanup(connection_id, connection, channel)
    end
  end
end
