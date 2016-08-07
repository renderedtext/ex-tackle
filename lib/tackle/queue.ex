defmodule Tackle.Queue do
  use AMQP
  require Logger

  def create_queues(channel, service, routing_key, delay) do
    create_nodelay_queue(channel, service, routing_key)
    create_delay_queue(channel, service, routing_key, delay)
    create_dead_queue(channel, service, routing_key)
  end

  def create_nodelay_queue(channel, service, routing_key) do
    queue_name = nodelay_queue_name(service, routing_key)

    Logger.info "Creating queue '#{queue_name}'"

    Queue.declare(channel, queue_name, durable: true)
    Exchange.direct(channel, service, durable: true)
  end

  def create_delay_queue(channel, service, routing_key, delay) do
    queue_name = delay_queue_name(service, routing_key, delay)

    Logger.info "Creating queue '#{queue_name}'"

    Queue.declare(channel, queue_name, [
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, service},
        {"x-dead-letter-routing-key", :longstr, routing_key},
        {"x-message-ttl", :long, delay * 1000}
      ]
    ])
  end

  def create_dead_queue(channel, service, routing_key) do
    queue_name = dead_queue_name(service, routing_key)

    Logger.info "Creating queue '#{queue_name}'"

    Queue.declare(channel, queue_name, durable: true)
  end

  def nodelay_queue_name(service, routing_key) do
    "#{service}.#{routing_key}.nodelay"
  end

  def delay_queue_name(service, delay) do
    "#{service}.#{routing_key}.delay.#{delay}"
  end

  def dead_queue_name(service, routing_key) do
    "#{service}.#{routing_key}.dead"
  end

end
