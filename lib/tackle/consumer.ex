defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t) :: any
  end

  defmacro __using__(options) do
    url = options[:url]

    exchange = options[:exchange]
    routing_key = options[:routing_key]
    service_name = options[:service_name]

    retry_delay = options[:retry_delay] || 10
    retry_limit = options[:retry_limit] || 10

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
        retry_delay = unquote(retry_delay)
        retry_limit = unquote(retry_limit)

        channel = Tackle.Channel.create(url)

        Tackle.Exchange.create_exchange_for_service(channel, service)
        Tackle.Exchange.bind(channel, service, remote_exchange, routing_key)

        queue = Tackle.Queue.create_queues(channel, service, routing_key, retry_delay)

        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)

        state = %{
          url: url,
          channel: channel,
          service_name: service_name,
          routing_key: routing_key,
          remote_exchange: remote_exchange,
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
            Tackle.DelayedRetry.retry(
              state.url,
              state.service_name,
              state.routing_key,
              payload,
              headers,
              state.retry_delays,
              state.retry_limit
            )

            AMQP.Basic.nack(state.channel, tag, [multiple: false, requeue: false])
        end
      end

    end
  end
end
