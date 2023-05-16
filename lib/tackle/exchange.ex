defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create(channel, name, opts \\ []) do
    # Used for declaring local service exchange
    name =
      opts[:routing_key]
      |> case do
        nil -> name
        routing_key -> "#{name}.#{routing_key}"
      end

    opts[:type]
    |> case do
      :fanout ->
        :ok = Exchange.fanout(channel, name, durable: true)

      :topic ->
        :ok = Exchange.topic(channel, name, durable: true)

      _ ->
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
    :ok = Exchange.direct(channel, remote_exchange, durable: true)

    Logger.info(
      "Binding '#{service_exchange}' to '#{remote_exchange}' with '#{routing_key}' routing keys"
    )

    :ok = Exchange.bind(channel, service_exchange, remote_exchange, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.info("Binding '#{queue}' to '#{service_exchange}' with '#{routing_key}' routing keys")

    :ok = Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end
end
