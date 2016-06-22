# Tackle

Tackle everything with Elixir!
Tackle is a simplified AMQP client.

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
