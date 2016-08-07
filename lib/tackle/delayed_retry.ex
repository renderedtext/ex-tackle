defmodule Tackle.DelayedRetry do
  use AMQP

  def retry(url, service, routing_key, payload, headers, retry_delay, retry_limit) do
    retry_count = retry_count_from_headers(headers)

    options = [
      persistent: true,
      headers: [
        retry_count: retry_count + 1
      ]
    ]

    if retry_count < retry_limit do
      Logger.info "Sending message to a delay queue"

      delay_queue_name = Tackle.Queue.delay_queue_name(service, retry_delay)

      publish(url, delay_queue_name, payload, options)
    else
      Logger.info "Sending message to a dead messages queue"

      dead_queue_name = Tackle.Queue.delay_queue_name(service)

      publish(url, dead_queue_name, payload, options)
    end
  end

  defp retry_count_from_headers(:undefined), do: 0
  defp retry_count_from_headers([]), do: 0
  defp retry_count_from_headers([{"retry_count", :long, count} | tail]), do: count
  defp retry_count_from_headers([_ | tail]), do: retry_count_from_headers(tail)

  def publish(url, queue, payload, options) do
    Logger.info "Connecting to '#{url}'"

    {:ok, connection} = AMQP.Connection.open(url)
    {:ok, channel} = Channel.open(connection)

    AMQP.Basic.publish(channel, "", queue, payload, options)

    AMQP.Connection.close(connection)
  end
end
