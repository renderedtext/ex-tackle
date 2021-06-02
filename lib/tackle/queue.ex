defmodule Tackle.Queue do
  use AMQP
  require Logger

  @dead_letter_timeout 604800000 # one week in milliseconds

  def create_queue(channel, service_exchange) do
    queue_name = service_exchange

    Logger.info "Creating queue '#{queue_name}'"

    {:ok, _} = Queue.declare(channel, queue_name, durable: true)

    queue_name
  end

  def create_delay_queue(channel, service_exchange, routing_key, delay) do
    queue_name = "#{service_exchange}.delay.#{delay}"

    Logger.info "Creating delay queue '#{queue_name}'"

    {:ok, _} =
      Queue.declare(channel, queue_name, [
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, service_exchange},
          {"x-dead-letter-routing-key", :longstr, routing_key},
          {"x-message-ttl", :long, delay * 1000}
        ]
      ])

    queue_name
  end

  def create_dead_queue(channel, service_exchange) do
    queue_name = "#{service_exchange}.dead"

    Logger.info "Creating dead queue '#{queue_name}'"

    {:ok, _} =
      Queue.declare(channel, queue_name, [
        durable: true,
        arguments: [
          {"x-message-ttl", :long, @dead_letter_timeout}
        ]
      ])

    queue_name
  end

end
