defmodule Tackle.Republisher do
  use AMQP
  require Logger

  def republish(url, queue, exchange, routing_key, count) do
    Logger.info("Connecting to '#{url}'")
    {:ok, connection} = AMQP.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    0..(count - 1)
    |> Enum.each(fn index ->
      IO.write("(#{index}) ")

      republish_one_message(channel, queue, exchange, routing_key)
    end)

    AMQP.Connection.close(connection)
  end

  defp republish_one_message(channel, queue, exchange, routing_key) do
    IO.write("Fetching message... ")

    case AMQP.Basic.get(channel, queue) do
      {:empty, _} ->
        IO.puts("no more messages")

      {:ok, message, %{delivery_tag: tag}} ->
        AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)
        AMQP.Basic.ack(channel, tag)

        IO.puts("republished")
    end
  end
end
