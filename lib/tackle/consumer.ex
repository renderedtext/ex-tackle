defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t) :: any
  end

  defmacro __using__(options) do
    url = options[:url]

    exchange = options[:exchange]
    routing_key = options[:routing_key]
    queue = options[:queue]

    retry_limit = options[:retry_limit] || 10
    retry_delay = options[:retry_delay] || 10

    quote do
      require Logger
      use GenServer
      use AMQP

      @behaviour Tackle.Consumer.Behaviour

      def start_link do
        GenServer.start_link(__MODULE__, {}, name: __MODULE__)
      end

      def init({}) do
        url         = unquote(url)
        queue_name  = unquote(queue)
        exchange    = unquote(exchange)
        routing_key = unquote(routing_key)

        Logger.info "Connecting to '#{url}'"
        channel = Tackle.Channel.create(url)

        Logger.info "Creating queue '#{queue_name}'"
        Tackle.Queue.create(channel, routing_key, queue_name)

        Logger.info "Bindind queue '#{queue_name}' to exchange '#{exchange}' with routing key '#{routing_key}'"
        Tackle.Queue.bind(channel, exchange, routing_key, queue_name)

        {:ok, channel}
      end

      def handle_info({:basic_consume_ok, _}, channel), do: {:noreply, channel}
      def handle_info({:basic_cancel, _},     channel), do: {:stop, :normal, channel}
      def handle_info({:basic_cancel_ok, _},  channel), do: {:noreply, channel}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, channel) do
        spawn fn -> consume(channel, tag, redelivered, payload) end

        {:noreply, channel}
      end

      defp consume(channel, tag, redelivered, payload) do
        try do
          handle_message(payload)

          Basic.ack(channel, tag)
        rescue
          e in RuntimeError ->
            Basic.reject channel, tag, requeue: not redelivered
        end
      end
    end
  end
end
