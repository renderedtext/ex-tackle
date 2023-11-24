defmodule Tackle.Republisher do
  use AMQP
  require Logger

  def republish(url, queue, exchange, routing_key, count) do
    {:ok, connection} = Tackle.Connection.open(url)
    channel = Tackle.Channel.create(connection)

    try do
      0..(count - 1)
      |> Enum.each(fn idx ->
        republish_one_message(channel, queue, exchange, routing_key, idx)
      end)
    after
      AMQP.Channel.close(channel)
      AMQP.Connection.close(connection)
    end
  end

  defp republish_one_message(channel, queue, exchange, routing_key, idx) do
    Logger.info("(#{idx}) Fetching message... from '#{inspect(queue)}' queue")

    case AMQP.Basic.get(channel, queue) do
      {:empty, _} ->
        Logger.info("No message found")

      {:ok, message, %{delivery_tag: tag}} ->
        Logger.info(
          "Republishing message to #{inspect(exchange)} exchange, #{inspect(queue)} queue with routing key #{inspect(routing_key)}"
        )

        :ok = AMQP.Basic.publish(channel, exchange, routing_key, message, persistent: true)
        :ok = AMQP.Basic.ack(channel, tag)

        Logger.info("Message republished: #{inspect(message)}")

      error ->
        error
    end
  end
end
