defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create(channel, exchange, opts \\ []) do
    {exchange_type, exchange_name} =
      exchange
      |> Tackle.Util.parse_exchange()

    name =
      opts[:routing_key]
      |> case do
        nil -> exchange_name
        routing_key -> "#{exchange_name}.#{routing_key}"
      end

    exchange_type
    |> case do
      :fanout ->
        :ok = Exchange.fanout(channel, name, durable: true)

      :topic ->
        :ok = Exchange.topic(channel, name, durable: true)

      :direct ->
        :ok = Exchange.direct(channel, name, durable: true)
    end

    name
  end

  def publish(channel, exchange, message, routing_key) do
    AMQP.Basic.publish(
      channel,
      exchange,
      routing_key,
      message,
      persistent: true
    )
  end

  def bind_to_remote(channel, service_exchange, remote_exchange, routing_key) do
    {exchange_type, exchange_name} =
      remote_exchange
      |> Tackle.Util.parse_exchange()
      |> case do
        {:fanout, name} = exchange ->
          :ok = Exchange.fanout(channel, name, durable: true)
          exchange

        {:topic, name} = exchange ->
          :ok = Exchange.topic(channel, name, durable: true)
          exchange

        {:direct, name} = exchange ->
          :ok = Exchange.direct(channel, name, durable: true)
          exchange
      end

    Logger.info(
      "Binding '#{service_exchange}' to '#{exchange_name}' with type '#{exchange_type}' with '#{routing_key}' routing keys"
    )

    :ok = Exchange.bind(channel, service_exchange, exchange_name, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.info("Binding '#{queue}' to '#{service_exchange}' with '#{routing_key}' routing keys")

    :ok = Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end
end
