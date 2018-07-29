defmodule Tackle.DelayedRetry do
  use AMQP
  require Logger

  def retry_count_from_headers(:undefined), do: 0
  def retry_count_from_headers([]), do: 0
  def retry_count_from_headers([{"retry_count", :long, count} | _tail]), do: count
  def retry_count_from_headers([_ | tail]), do: retry_count_from_headers(tail)

  def publish(url, queue, payload, options) do
    Logger.info("Connecting to '#{Tackle.DebugHelper.safe_uri(url)}'")

    {:ok, connection} = AMQP.Connection.open(url)
    {:ok, channel} = Channel.open(connection)

    AMQP.Basic.publish(channel, "", queue, payload, options)

    AMQP.Connection.close(connection)
  end
end
