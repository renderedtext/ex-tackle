defmodule Tackle.Queue do
  use AMQP
  require Logger

  # one week in milliseconds
  @dead_letter_timeout 604_800_000

  def create_queue(channel, queue_name, opts \\ []) do
    defaults = [
      durable: true
    ]

    opts = Keyword.merge(defaults, opts)

    Logger.info("Creating queue '#{queue_name}'")

    {:ok, _} = Queue.declare(channel, queue_name, opts)

    queue_name
  end

  def create_delay_queue(
        channel,
        dead_letter_exchange_name,
        queue_name,
        routing_key,
        delay,
        opts \\ []
      ) do
    delay_queue_name = "#{queue_name}.delay.#{delay}"

    defaults = [
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, dead_letter_exchange_name},
        {"x-dead-letter-routing-key", :longstr, routing_key},
        {"x-message-ttl", :long, delay * 1000}
      ]
    ]

    opts = Keyword.merge(defaults, opts)

    Logger.info("Creating delay queue '#{delay_queue_name}'")

    {:ok, _} = Queue.declare(channel, delay_queue_name, opts)

    delay_queue_name
  end

  def create_dead_queue(channel, queue_name, opts \\ []) do
    dead_queue_name = "#{queue_name}.dead"

    defaults = [
      durable: true,
      arguments: [
        {"x-message-ttl", :long, @dead_letter_timeout}
      ]
    ]

    opts = Keyword.merge(defaults, opts)

    Logger.info("Creating dead queue '#{dead_queue_name}'")

    {:ok, _} = Queue.declare(channel, dead_queue_name, opts)

    dead_queue_name
  end
end
