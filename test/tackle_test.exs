defmodule TackleTest do
  use ExUnit.Case, async: false

  test "rapid message publishing has good performance" do
    msg = '{ "tackle" => "me" }'

    {:ok, c} = Tackle.Connection.open(:publisher, "amqp://localhost")
    channel  = Tackle.Channel.create(c)
    exchange = Tackle.Exchange.create(channel, "rapid-exchange")

    ms = :timer.tc(fn ->
      (1..1_000) |> Enum.each(fn _ ->
        Tackle.Exchange.publish(channel, exchange, msg, "hello-kye")
      end)
    end) |> elem(0)

    IO.puts "Performance: #{ms} us"

    # we don't care about the exact values, just the general ballpark perf
    # when sending to localhost. It is usually bellow 10ms, but I am already
    # happy with 50ms.
    assert ms/1000 < 50
  end
end
