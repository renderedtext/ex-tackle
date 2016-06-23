# Tackle

Tackle everything with Elixir!
Tackle is a simplified AMQP client.

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
    queue: "test-consumer-queue"

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
