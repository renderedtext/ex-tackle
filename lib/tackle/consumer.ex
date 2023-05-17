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
    exchange_type = options[:exchange_type] || :direct

    retry_delay = options[:retry_delay] || 10
    retry_limit = options[:retry_limit] || 10

    prefetch_count = options[:prefetch_count] || @prefetch_count

    connection_id = options[:connection_id] || :default
    queue_name = options[:queue_name]

    quote do
      @behaviour Tackle.Consumer.Behaviour

      require Logger
      use GenServer

      def start_link(opts \\ []) do
        process_name = Keyword.get(opts, :process_name, __MODULE__)
        GenServer.start_link(__MODULE__, [], name: process_name)
      end

      def init(_) do
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
        exchange_type = unquote(exchange_type)

        {:ok, connection} = Tackle.Connection.open(connection_id, url)
        # Get notifications when the connection goes down
        Process.monitor(connection.pid)
        channel = Tackle.Channel.create(connection, prefetch_count)

        remote_exchange = unquote(exchange)

        service_exchange =
          Tackle.Exchange.create(
            channel,
            service,
            routing_key: routing_key,
            type: exchange_type
          )

        Tackle.Exchange.bind_to_remote(
          channel,
          service_exchange,
          remote_exchange,
          routing_key
        )

        queue_name =
          unquote(queue_name)
          |> case do
            nil -> service_exchange
            :dynamic -> unique_name(20)
            name -> name
          end

        queue = Tackle.Queue.create_queue(channel, queue_name)
        dead_queue = Tackle.Queue.create_dead_queue(channel, queue_name)

        delay_queue =
          Tackle.Queue.create_delay_queue(channel, queue_name, routing_key, retry_delay)

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
      def handle_info({:basic_cancel, _}, state), do: {:stop, :normal, state}
      def handle_info({:basic_cancel_ok, _}, state), do: {:noreply, state}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag, headers: headers}}, state) do
        consume_callback = fn ->
          handle_message(payload)
          :ok = AMQP.Basic.ack(state.channel, tag)
        end

        error_callback = fn reason ->
          Logger.error("Consumption failed: #{inspect(reason)}; payload: #{inspect(payload)}")
          retry(state, payload, headers)
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

      defp retry(state, payload, headers) do
        retry_count = Tackle.DelayedRetry.retry_count_from_headers(headers)

        options = [
          persistent: true,
          headers: [
            retry_count: retry_count + 1
          ]
        ]

        if retry_count < state.retry_limit do
          Logger.info("Sending message to a delay queue")

          Tackle.DelayedRetry.publish(
            state.url,
            state.delay_queue,
            payload,
            options
          )
        else
          Logger.info("Sending message to a dead messages queue")

          Tackle.DelayedRetry.publish(
            state.url,
            state.dead_queue,
            payload,
            options
          )
        end
      end

      defp unique_name(length) do
        :crypto.strong_rand_bytes(length)
        |> Base.encode32(padding: false)
      end
    end
  end
end
