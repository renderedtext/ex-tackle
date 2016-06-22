# Tackle

Tackle everything with Elixir! Simplified AMQP client.

``` elixir
defmodule MyConsumer do
  use Tackle.Consumer,
    url: "amqp://localhost",
    exchange: "my-exchange",
    routing_key: "my-messages",
    queue: "my-consumer-queue"

  def handle_message(message) do
    IO.puts "A message arrived. Life is good!"

    IO.puts message
  end
end
```
