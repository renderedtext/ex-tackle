# Tackle

[![Build Status](https://semaphoreci.com/api/v1/projects/ed643936-2795-4ac4-b225-7d33947d4a54/862273/badge.svg)](https://semaphoreci.com/renderedtext/ex-tackle)

Tackles the problem of processing asynchronous jobs in reliable manner
by relying on RabbitMQ.

You should also take a look at [Ruby Tackle](https://github.com/renderedtext/tackle).

## Why should I use tackle?

- It is ideal for fast microservice prototyping
- It uses sane defaults for queue and exchange creation
- It retries messages that fail to be processed
- It stores unprocessed messages into a __dead__ queue for later inspection

## Installation

Add the following to the list of your dependencies:

``` elixir
def deps do
  [
    {:tackle, github: "renderedtext/ex-tackle"}
  ]
end
```

Also, add it to the list of your applications:

``` elixir
def application do
  [applications: [:tackle]]
end
```

## Publishing messages to an exchange

To publish a message to an exchange:

``` elixir
options = %{
  url: "amqp://localhost",
  exchange: "test-exchange",
  routing_key: "test-messages",
}

Tackle.publish("Hi!", options)
```

## Consuming messages from an exchange

First, declare a consumer module:

``` elixir
defmodule TestConsumer do
  use Tackle.Consumer,
    url: "amqp://localhost",
    exchange: "test-exchange",
    routing_key: "test-messages",
    service: "my-service"

  def handle_message(message) do
    IO.puts "A message arrived. Life is good!"

    IO.puts message
  end
end
```

And then start it to consume messages:

``` elixir
TestConsumer.start_link
```

## Rescuing dead messages

If you consumer is broken, or in other words raises an exception while handling
messages, your messages will end up in a dead messages queue.

To rescue those messages, you can use `Tackle.republish`:

``` elixir
dead_queue_name = "my-service.test-message.dead"

options = {
  url: "amqp://localhost",
  qeueu: dead_queue_name,
  exchange: "test-exchange",
  routing_key: "test-messages",
  count: 1
}

Tackle.republish(options)
```

The above will pull one message from the `dead_queue_name` and publish it on the
`test-exchange` exchange with `test-messages` routing key.

To republish multiple messages, use a bigger `count` number.
