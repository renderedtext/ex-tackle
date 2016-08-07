defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t) :: any
  end

  defmacro __using__(options) do
    url = options[:url]

    exchange = options[:exchange]
    routing_key = options[:routing_key]
    service_name = options[:service_name]

    retry_delays = options[:retry_delays] || [30, 3600]
    retry_limits = options[:retry_limits] || [10, 10]

    quote do
      @behaviour Tackle.Consumer.Behaviour

      require Logger
      use GenServer

      def start_link do
        GenServer.start_link(__MODULE__, {}, name: __MODULE__)
      end

      def init({}) do
        url = unquote(url)
        service = unquote(service_name)
        remote_exchange = unquote(exchange)
        routing_key = unquote(routing_key)
        retry_delays = unquote(retry_delay)
        retry_limits = unquote(retry_limit)

        channel = Tackle.Channel.create(url)

        Tackle.Exchange.create_exchange_for_service(channel, service)
        Tackle.Exchange.bind(channel, service, remote_exchange, routing_key)

        queue = Tackle.Queue.create_queues(channel, service, routing_key, delays)

        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)

        state = %{
          channel: channel,
          queue_name: queue_name,
          routing_key: routing_key,
          exchange: exchange,
          retry_delay: retry_delay,
          retry_limit: retry_limit
        }

        {:ok, state}
      end

      def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
      def handle_info({:basic_cancel, _},     state), do: {:stop, :normal, state}
      def handle_info({:basic_cancel_ok, _},  state), do: {:noreply, state}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, headers: headers}}, state) do
        retry_count = retry_count_from_headers(headers)

        spawn fn -> consume(state, tag, retry_count, payload) end

        {:noreply, state}
      end

      defp retry_count_from_headers(:undefined), do: 0
      defp retry_count_from_headers([]), do: 0
      defp retry_count_from_headers([{"retry_count", :long, retry_count} | tail]), do: retry_count
      defp retry_count_from_headers([_ | tail]), do: retry_count_from_headers(tail)

      defp consume(state, tag, retry_count, payload) do
        try do
          handle_message(payload)

          AMQP.Basic.ack(state.channel, tag)
        rescue
          _ ->
            delayed_retry(state, payload, retry_count)
            AMQP.Basic.nack(state.channel, tag, [multiple: false, requeue: false])
        end
      end

      defp delayed_retry(state, payload, retry_count)  do
        if retry_count < state.retry_limit do
          Logger.info "Sending message to the dead letters. Retry count: '#{retry_count}'"

          dead_exchange = Tackle.Queue.dead_letter_exchange_name(state.exchange)

          options = [
            persistent: true,
            headers: [
              retry_count: retry_count + 1
            ]
          ]

          AMQP.Basic.publish(state.channel, dead_exchange, state.routing_key, payload, options)
        else
          Logger.info "Reached #{retry_count} retries. Discarding message"
        end
      end

    end
  end
end
