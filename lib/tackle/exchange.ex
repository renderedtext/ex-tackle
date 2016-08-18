defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create(channel, service_name, routing_key) do
    name = "#{service_name}.#{routing_key}"

    Exchange.direct(channel, name, durable: true)

    name
  end

  def bind_to_remote(channel, service_exchange, remote_exchange, routing_key) do
    Exchange.direct(channel, remote_exchange, durable: true)

    Logger.info "Binding '#{service_exchange}' to '#{remote_exchange}' with '#{routing_key}' routing keys"

    Exchange.bind(channel, service_exchange, remote_exchange, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.info "Binding '#{queue}' to '#{service_exchange}' with '#{routing_key}' routing keys"

    Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end

end
