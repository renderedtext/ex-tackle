defmodule Tackle.DelayedRetry do
  use AMQP
  require Logger

  def retry_count_from_headers(:undefined), do: 0
  def retry_count_from_headers([]), do: 0
  def retry_count_from_headers([{"retry_count", :long, count} | _]), do: count
  def retry_count_from_headers([_ | tail]), do: retry_count_from_headers(tail)

  def publish(url, queue, payload, options) do
    connection_id = options[:connection_id] || :default

    {:ok, connection} = Tackle.Connection.open(connection_id, url)
    {:ok, channel} = Channel.open(connection)

    try do
      :ok = AMQP.Basic.publish(channel, "", queue, payload, options)
    after
      Tackle.Util.cleanup(connection_id, connection, channel)
    end
  end
end
