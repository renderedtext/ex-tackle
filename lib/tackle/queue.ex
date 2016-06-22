defmodule Tackle.Queue do
  use AMQP

  def create(channel, exchange, routing_key, queue_name, retry_delay) do
    Queue.declare(channel, queue_name, durable: true)

    Queue.declare(channel, dead_letter_queue_name(queue_name), [
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, exchange},
        {"x-dead-letter-routing-key", :longstr, routing_key},
        {"x-message-ttl", :long, retry_delay * 1000}
      ]
    ])
  end

  def bind(channel, exchange, routing_key, queue_name) do
    dead_exchange = dead_letter_exchange_name(exchange)
    dead_queue = dead_letter_queue_name(queue_name)

    Exchange.fanout(channel, dead_exchange, durable: true)
    Exchange.direct(channel, exchange, durable: true)

    Queue.bind(channel, dead_queue, dead_exchange, routing_key: routing_key)
    Queue.bind(channel, queue_name, exchange, routing_key: routing_key)
  end

  def dead_letter_exchange_name(exchange) do
    "#{exchange}.dead_letter_exchange"
  end

  def dead_letter_queue_name(queue_name) do
    "#{queue_name}_dead_letters"
  end

end
