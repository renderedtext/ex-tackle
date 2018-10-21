defmodule TackleTest do
  use ExUnit.Case, async: false

  test "rapid message publishing has good performance" do
    msg = "{ \"tackle\" => \"me\" }"

    {:ok, c} = Tackle.Connection.open(:publisher, "amqp://localhost")
    channel  = Tackle.Channel.create(c)
    exchange = Tackle.Exchange.create(channel, "rapid-exchange")

    ms = :timer.tc(fn ->
      (1..100_000) |> Enum.each(fn i ->
        Tackle.Exchange.publish(channel, exchange, msg, "hello-kye")
      end)
    end) |> elem(0)

    IO.puts "Performance: #{ms/1000} ms"

    # we don't care about the exact values, we just want to make sure that
    # we can send 100_000 under 1 second to a localhost
    assert ms/1000 < 1000
  end
end
