defmodule Tackle.Republisher do
  use AMQP
  require Logger

  @deprecated "Use Tackle.republish/1 instead"
  def republish(url, queue, exchange, routing_key, count) when is_binary(url) do
    connection_id = :default
    {:ok, connection} = Tackle.Connection.open(connection_id, url)
    channel = Tackle.Channel.create(connection)

    try do
      republish(channel, queue, exchange, routing_key, count)
    after
      Tackle.Util.cleanup(connection_id, connection, channel)
    end
  end

  def republish(channel, queue, exchange, routing_key, count) do
    0..(count - 1)
    |> Enum.each(fn idx ->
      republish_one_message(channel, queue, exchange, routing_key, idx)
    end)
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
