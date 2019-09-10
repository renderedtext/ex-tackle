defmodule Tackle.Consumer do
  defmodule Behaviour do
    @callback handle_message(String.t()) :: any
  end

  defmacro __using__(options) do
    quote do
      # let genserver 1 sec for cleanup work
      use GenServer, shutdown: 1_000
      @behaviour Tackle.Consumer.Behaviour

      require Logger

      def start_link, do: start_link([])

      def start_link(overrides) do
        GenServer.start_link(__MODULE__, overrides, name: __MODULE__)
      end

      def init(overrides) do
        default_options = unquote(options)
        options = Keyword.merge(default_options, overrides)

        # so, we can cleanup with terminate callback
        Process.flag(:trap_exit, true)

        url = options[:url]
        connection_id = options[:connection_id] || :default
        # sequential message handling by default
        prefetch_count = options[:prefetch_count] || 1

        service = options[:service]
        remote_exchange_name = options[:exchange]
        routing_key = options[:routing_key]

        retry_delay = options[:retry_delay] || 10
        retry_limit = options[:retry_limit] || 10

        channel = {:ok, connection} = Tackle.Connection.open(connection_id, url)
        channel = Tackle.Channel.create(connection, prefetch_count)

        service_exchange_name =
          Tackle.Exchange.create_service_exchange(channel, service, routing_key)

        Tackle.Exchange.bind_to_remote(
          channel,
          service_exchange_name,
          remote_exchange_name,
          routing_key
        )

        consume_from_queue = Tackle.Queue.create_queue(channel, service_exchange_name)

        Tackle.Exchange.bind_to_queue(
          channel,
          service_exchange_name,
          consume_from_queue,
          routing_key
        )

        delay_queue_name =
          Tackle.Queue.create_delay_queue(
            channel,
            service_exchange_name,
            routing_key,
            retry_delay
          )

        dead_queue_name = Tackle.Queue.create_dead_queue(channel, service_exchange_name)

        # start actual consuming
        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, consume_from_queue)

        state = %{
          url: url,
          channel: channel,
          delay_queue: delay_queue_name,
          dead_queue: dead_queue_name,
          retry_limit: retry_limit
        }

        {:ok, state}
      end

      def terminate(reason, state) do
        state.channel |> Tackle.Channel.close()
        # state.channel.conn |> Tackle.Connection.close()
      end

      def handle_info({:basic_consume_ok, _}, state), do: {:noreply, state}
      def handle_info({:basic_cancel, _}, state), do: {:stop, :normal, state}
      def handle_info({:basic_cancel_ok, _}, state), do: {:stop, :normal, state}

      def handle_info({:basic_deliver, payload, %{delivery_tag: tag} = message_metadata}, state) do
        consume_callback = fn ->
          handle_message(payload)
          AMQP.Basic.ack(state.channel, tag)
        end

        error_callback = fn reason ->
          Logger.error("Consumption failed: #{inspect(reason)}; payload: #{inspect(payload)}")
          retry(state, payload, message_metadata, reason)
          AMQP.Basic.nack(state.channel, tag, multiple: false, requeue: false)
        end

        spawn(fn -> delivery_handler(consume_callback, error_callback) end)

        {:noreply, state}
      end

      def delivery_handler(consume_callback, error_callback) do
        Process.flag(:trap_exit, true)

        me = self()
        safe_consumer = fn -> safe_consumer(me, consume_callback) end

        pid = spawn_link(safe_consumer)

        receive do
          :ok ->
            :ok

          {:retry, reason} ->
            error_callback.(reason)

          {:EXIT, ^pid, :normal} ->
            :ok

          {:EXIT, ^pid, :shutdown} ->
            :ok

          {:EXIT, ^pid, {:shutdown, _reason}} ->
            :ok

          {:EXIT, ^pid, reason} ->
            error_callback.(reason)
        end
      end

      defp safe_consumer(receiver, consume_callback) do
        # try not to die, so we do not get all the notifications
        result =
          try do
            consume_callback.()
            :ok
          catch
            # retry on exit and throw(:retry) or throw({:retry, reason})
            :throw, :retry ->
              {:retry, {:retry_requested, __STACKTRACE__}}

            :throw, {:retry, reason} ->
              {:retry, {reason, __STACKTRACE__}}
          end

        # send result back to the receiver, so we can retry if needed
        send(receiver, result)
      end

      defp retry(
             state,
             payload,
             %{headers: headers} = message_metadata,
             error_reason
           ) do
        retry_count = Tackle.DelayedRetry.retry_count_from_headers(headers)
        # IO.inspect("Retry #{retry_count + 1}: #{inspect(error_reason)}")

        options = [
          persistent: true,
          headers: [
            retry_count: retry_count + 1
          ]
        ]

        Task.start(fn ->
          current_attempt = retry_count + 1
          max_number_of_attemts = state.retry_limit + 1
          {may_be_erlang_error, stacktrace} = error_reason
          elixir_exception = Exception.normalize(:error, may_be_erlang_error, stacktrace)

          on_error(
            payload,
            message_metadata,
            {elixir_exception, stacktrace},
            current_attempt,
            max_number_of_attemts
          )
        end)

        if retry_count < state.retry_limit do
          Logger.debug("Sending message to a delay queue")

          Tackle.DelayedRetry.publish(
            state.url,
            state.delay_queue,
            payload,
            options
          )
        else
          Logger.debug("Sending message to a dead messages queue")

          Tackle.DelayedRetry.publish(
            state.url,
            state.dead_queue,
            payload,
            options
          )
        end
      end

      # TODO: Test me!!!
      defp on_error(
             payload,
             message_metadata,
             error_reason,
             current_attempt,
             max_number_of_attemts
           ),
           do: :ok

      defoverridable(on_error: 5)
    end
  end
end
