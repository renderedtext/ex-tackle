defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t) :: any
  end

  defmacro __using__(options) do
    url = options[:url]

    exchange = options[:exchange]
    routing_key = options[:routing_key]
    service = options[:service]

    retry_delay = options[:retry_delay] || 10
    retry_limit = options[:retry_limit] || 10

    #Module.overridable(__MODULE__, [{"before_consume", 1}])

    quote do
      @behaviour Tackle.Consumer.Behaviour

      require Logger
      use GenServer

      def start_link do
        GenServer.start_link(__MODULE__, {}, name: __MODULE__)
      end

      def init({}) do
        url = unquote(url)
        service = unquote(service)
        routing_key = unquote(routing_key)
        retry_delay = unquote(retry_delay)
        retry_limit = unquote(retry_limit)

        {:ok, connection} = AMQP.Connection.open(url)
        channel = Tackle.Channel.create(connection)

        remote_exchange  = unquote(exchange)
        service_exchange = Tackle.Exchange.create(channel, service, routing_key)

        Tackle.Exchange.bind_to_remote(
          channel,
          service_exchange,
          remote_exchange,
          routing_key
        )

        queue       = Tackle.Queue.create_queue(channel, service_exchange)
        dead_queue  = Tackle.Queue.create_dead_queue(channel, service_exchange)
        delay_queue = Tackle.Queue.create_delay_queue(channel, service_exchange, routing_key, retry_delay)

        Tackle.Exchange.bind_to_queue(
          channel,
          service_exchange,
          queue,
          routing_key
        )

        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)

        state = %{
          url: url,
          channel: channel,
          delay_queue: delay_queue,
          dead_queue: dead_queue,
          retry_limit: retry_limit
        }

        {:ok, state}
      end

      def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
      def handle_info({:basic_cancel, _},     state), do: {:stop, :normal, state}
      def handle_info({:basic_cancel_ok, _},  state), do: {:noreply, state}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, headers: headers}}, state) do

        spawn fn ->
          consume(state, tag, headers, payload)
        end

        {:noreply, state}
      end

      defp consume(state, tag, headers, payload) do
        try do
          ######################################
          #ITS OVER HERE!
          ######################################
          #before_consume(payload)
          #|> handle_message
          handle_message(payload)

          AMQP.Basic.ack(state.channel, tag)
        rescue
          _ ->
            retry(state, payload, headers)

            AMQP.Basic.nack(state.channel, tag, [multiple: false, requeue: false])
        end
      end

      defp retry(state, payload, headers) do
        retry_count = Tackle.DelayedRetry.retry_count_from_headers(headers)

        options = [
          persistent: true,
          headers: [
            retry_count: retry_count + 1
          ]
        ]

        if retry_count < state.retry_limit do
          Logger.info "Sending message to a delay queue"

          Tackle.DelayedRetry.publish(
            state.url,
            state.delay_queue,
            payload,
            options)
        else
          Logger.info "Sending message to a dead messages queue"

          Tackle.DelayedRetry.publish(
            state.url,
            state.dead_queue,
            payload,
            options)
        end
      end

      #def before_consume(message) do
      #  message
      #end
    end
  end
end
