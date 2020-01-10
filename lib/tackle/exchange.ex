defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create(channel, name) do
    :ok = Exchange.direct(channel, name, durable: true)

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

  # Used for declaring local service exchange
  def create(channel, service_name, routing_key) do
    create(channel, "#{service_name}.#{routing_key}")
  end

  def bind_to_remote(channel, service_exchange, remote_exchange, routing_key) do
    :ok = Exchange.direct(channel, remote_exchange, durable: true)

    Logger.info "Binding '#{service_exchange}' to '#{remote_exchange}' with '#{routing_key}' routing keys"

    :ok = Exchange.bind(channel, service_exchange, remote_exchange, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.info "Binding '#{queue}' to '#{service_exchange}' with '#{routing_key}' routing keys"

    :ok = Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end

end
