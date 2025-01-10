defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t()) :: any
  end

  # Sequential message handling by default
  @prefetch_count 1

  defmacro __using__(options) do
    url = options[:url]

    exchange = options[:exchange]

    routing_key = options[:routing_key]
    service = options[:service]

    retry_delay = options[:retry_delay] || 10
    retry_limit = options[:retry_limit] || 10

    prefetch_count = options[:prefetch_count] || @prefetch_count

    connection_id = options[:connection_id] || :default
    queue = options[:queue]

    queue_opts = options[:queue_opts] || []
    exchange_opts = options[:exchange_opts] || []

    create_dead_letter_queue? = Keyword.get(options, :dead_letter_queue, true)

    quote do
      @behaviour Tackle.Consumer.Behaviour

      require Logger
      use GenServer

      def start_link(opts \\ []) do
        process_name = Keyword.get(opts, :process_name, __MODULE__)
        GenServer.start_link(__MODULE__, [process_name: process_name], name: process_name)
      end

      def init(opts) do
        Logger.info("Starting consumer #{inspect(opts[:process_name])}")
        url = unquote(url)
        service_name_prefix = Application.get_env(:tackle, :service_name_prefix)

        service =
          if service_name_prefix do
            "#{service_name_prefix}.#{unquote(service)}"
          else
            unquote(service)
          end

        routing_key = unquote(routing_key)
        retry_delay = unquote(retry_delay)
        retry_limit = unquote(retry_limit)
        prefetch_count = unquote(prefetch_count)
        connection_id = unquote(connection_id)
        exchange = unquote(exchange)
        exchange_opts = unquote(exchange_opts)
        queue = unquote(queue)
        queue_opts = unquote(queue_opts)
        create_dead_letter_queue? = unquote(create_dead_letter_queue?)

        {exchange_type, exchange_name} =
          exchange
          |> Tackle.Util.parse_exchange()

        {:ok, connection} = Tackle.Connection.open(connection_id, url)
        # Get notifications when the connection goes down
        Process.monitor(connection.pid)
        channel = Tackle.Channel.create(connection, prefetch_count)
        Process.monitor(channel.pid)

        service_exchange_name = "#{service}.#{routing_key}"

        Tackle.Exchange.create(
          channel,
          {exchange_type, service_exchange_name},
          exchange_opts
        )

        Tackle.Exchange.bind_to_remote(
          channel,
          service_exchange_name,
          exchange,
          routing_key,
          exchange_opts
        )

        queue = Tackle.Util.resolve_queue(unquote(queue), service_exchange_name)
        main_queue = Tackle.Queue.create_queue(channel, queue, queue_opts)

        dead_queue =
          if create_dead_letter_queue? do
            Tackle.Queue.create_dead_queue(channel, queue, queue_opts)
          else
            nil
          end

        delay_queue =
          if create_dead_letter_queue? do
            Tackle.Queue.create_delay_queue(
              channel,
              service_exchange_name,
              queue,
              routing_key,
              retry_delay,
              queue_opts
            )
          else
            nil
          end

        Tackle.Exchange.bind_to_queue(
          channel,
          service_exchange_name,
          main_queue,
          routing_key
        )

        {:ok, consumer_tag} = AMQP.Basic.consume(channel, queue)

        state = %{
          url: url,
          channel: channel,
          has_dead_letter?: create_dead_letter_queue?,
          delay_queue: delay_queue,
          dead_queue: dead_queue,
          retry_limit: retry_limit,
          consumer_tag: consumer_tag
        }

        {:ok, state}
      end

      def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
      def handle_info({:basic_cancel, _}, state), do: {:stop, :normal, state}
      def handle_info({:basic_cancel_ok, _}, state), do: {:noreply, state}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, headers: headers}}, state) do
        consume_callback = fn ->
          handle_message(payload)
          :ok = AMQP.Basic.ack(state.channel, tag)
        end

        error_callback = fn reason ->
          Logger.error("Consumption failed: #{inspect(reason)}; payload: #{inspect(payload)}")

          if state.has_dead_letter? do
            retry(state, payload, headers)
          end

          :ok = AMQP.Basic.nack(state.channel, tag, multiple: false, requeue: false)
        end

        spawn(fn -> delivery_handler(consume_callback, error_callback) end)

        {:noreply, state}
      end

      def delivery_handler(consume_callback, error_callback) do
        Process.flag(:trap_exit, true)

        pid = spawn_link(consume_callback)

        receive do
          {:EXIT, pid, :normal} -> :ok
          {:EXIT, pid, reason} -> error_callback.(reason)
        end
      end

      def handle_info({:DOWN, _, :process, _pid, reason}, _) do
        # Stop GenServer. Will be restarted by Supervisor.
        {:stop, {:connection_lost, reason}, nil}
      end

      def terminate(_reason, state) do
        AMQP.Basic.cancel(state.channel, state.consumer_tag)
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
          Logger.info("Sending message to a delay queue: #{state.delay_queue}")

          Tackle.DelayedRetry.publish(
            state.url,
            state.delay_queue,
            payload,
            options
          )
        else
          Logger.info("Sending message to a dead messages queue: #{state.dead_queue}")

          Tackle.DelayedRetry.publish(
            state.url,
            state.dead_queue,
            payload,
            options
          )
        end
      end

      def handle_info(message, state) do
        Logger.info("Received unknown message: #{inspect(message)}")
        {:noreply, state}
      end
    end
  end
end
