defmodule Tackle.Exchange do
  use AMQP
  require Logger

  @exchange_type Application.get_env(:tackle, :exchange_type, :direct)

  def create_service_exchange(channel, service_name, routing_key) do
    exchange_name = "#{service_name}.#{routing_key}"
    create(channel, exchange_name)
  end

  def create_remote_exchange(channel, exchange_name), do: create(channel, exchange_name)

  def create(channel, exchange_name) do
    Exchange.declare(channel, exchange_name, @exchange_type, durable: true)

    exchange_name
  end

  def bind_to_remote(channel, service_exchange, remote_exchange, routing_key) do
    create_remote_exchange(channel, remote_exchange)

    Logger.debug(
      "Binding '#{service_exchange}' to '#{remote_exchange}' with '#{routing_key}' routing keys"
    )

    Exchange.bind(channel, service_exchange, remote_exchange, routing_key: routing_key)
  end

  def bind_to_queue(channel, service_exchange, queue, routing_key) do
    Logger.debug("Binding '#{queue}' to '#{service_exchange}' with '#{routing_key}' routing keys")

    Queue.bind(channel, queue, service_exchange, routing_key: routing_key)
  end
end
