defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create(channel, exchange, opts \\ []) do
    {exchange_type, exchange_name} =
      exchange
      |> Tackle.Util.parse_exchange()

    default_opts = [
      durable: true
    ]

    opts = Keyword.merge(default_opts, opts)

    Logger.info("Creating '#{exchange_name}' exchange with type '#{exchange_type}'")

    exchange_type
    |> case do
      :fanout ->
        :ok = Exchange.fanout(channel, exchange_name, opts)

      :topic ->
        :ok = Exchange.topic(channel, exchange_name, opts)

      :direct ->
        :ok = Exchange.direct(channel, exchange_name, opts)
    end

    exchange_name
  end

  def publish(channel, exchange, message, routing_key) do
    Logger.debug(
      "Publishing to exchange '#{exchange}' message '#{inspect(message)}' with routing key '#{routing_key}'"
    )

    AMQP.Basic.publish(
      channel,
      exchange,
      routing_key,
      message,
      persistent: true
    )
  end

  def bind_to_remote(channel, service_exchange, remote_exchange, routing_key, opts \\ []) do
    default_opts = [
      durable: true
    ]

    opts = Keyword.merge(default_opts, opts)

    {exchange_type, exchange_name} =
      remote_exchange
      |> Tackle.Util.parse_exchange()
      |> case do
        {:fanout, name} = exchange ->
          :ok = Exchange.fanout(channel, name, opts)
          exchange

        {:topic, name} = exchange ->
          :ok = Exchange.topic(channel, name, opts)
          exchange

        {:direct, name} = exchange ->
          :ok = Exchange.direct(channel, name, opts)
          exchange
      end

    Logger.info(
      "Binding '#{service_exchange}' exchange to '#{exchange_name}' exchange with type '#{exchange_type}' with '#{routing_key}' routing keys"
    )

    :ok = Exchange.bind(channel, service_exchange, exchange_name, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.info(
      "Binding '#{queue}' queue to '#{service_exchange}' exchange with '#{routing_key}' routing keys"
    )

    :ok = Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end
end
