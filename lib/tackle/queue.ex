defmodule Tackle.Queue do
  use AMQP

  def create(channel, routing_key, queue_name) do
    dead_letter_queue = "#{queue_name}_dead_letters"

    Queue.declare(channel, dead_letter_queue, durable: true)

    Queue.declare(channel, queue_name, [
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, dead_letter_queue},
        {"x-dead-letter-routing-key", :longstr, routing_key}
      ]
    ])
  end

  def bind(channel, exchange, routing_key, queue_name) do
    Exchange.direct(channel, exchange, durable: true)

    Queue.bind(channel, queue_name, exchange, routing_key: routing_key)
  end

end
