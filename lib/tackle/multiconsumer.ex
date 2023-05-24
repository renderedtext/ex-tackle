defmodule Tackle.Multiconsumer do
  @doc """
  A generalization of a Tackle.Consumer. Where a Tackle.Consumer can consume
  one type of message, from one exchange, with one routing key, the Tackle.Multiconsumer
  can handle multi exchanges, routing keys and message types.
  Example:
    defmodule Example do
      use Tackle.Multiconsumer,
        url: Application.get_env(:amqp_url),
        service: "example",
        routes: [
          {"user-exchange", "created", :handle_user_events},
          {"user-exchange", "updated", :handle_user_events},
          {"project-exchange", "created", :handle_project_events},
          {"project-exchange", "updated", :handle_project_events},
        ]
      def handle_user_events(msg) do
        IO.inspect msg
      end
      def handle_project_events(msg) do
        IO.inspect msg
      end
    end
  """

  defmacro __using__(opts) do
    caller_module = __CALLER__.module

    #
    # Create a consumer module for all routes
    #
    consumers =
      Enum.map(opts[:routes], fn route ->
        {_, _, [exchange, routing_key, _]} = route

        {_exchange_type, exchange_name} =
          exchange
          |> Tackle.Util.parse_exchange()

        queue_name = opts[:queue_name]

        module_name =
          Tackle.Multiconsumer.consumer_module_name(caller_module, exchange_name, routing_key)

        quote do
          defmodule unquote(module_name) do
            use Tackle.Consumer,
              url: unquote(opts[:url]),
              service: "#{unquote(opts[:service])}.#{unquote(exchange_name)}",
              exchange: unquote(exchange),
              routing_key: unquote(routing_key),
              queue_name: unquote(queue_name)

            def handle_message(msg) do
              {_, _, destination_fun} = unquote(route)

              apply(unquote(caller_module), destination_fun, [msg])
            end
          end
        end
      end)

    #
    # Create a supervisor and start all consumers
    #
    supervisor =
      quote do
        use Supervisor
        require Logger

        def init(stack) do
          {:ok, stack}
        end

        def start_link(_ \\ nil) do
          import Supervisor.Spec

          children =
            unquote(opts[:routes])
            |> Enum.map(fn {exchange, routing_key, _} ->
              {_exchange_type, exchange_name} =
                exchange
                |> Tackle.Util.parse_exchange()

              Tackle.Multiconsumer.consumer_module_name(
                unquote(caller_module),
                exchange_name,
                routing_key
              )
            end)

          opts = [strategy: :one_for_one, name: __MODULE__]

          Supervisor.start_link(children, opts)
        end
      end

    #
    # Return generated code, multiple consumer modules, and start_link
    # for starting a supervisor.
    #
    consumers ++ [supervisor]
  end

  def consumer_module_name(caller_module, exchange, routing_key) do
    :"#{caller_module}.#{exchange}.#{routing_key}"
  end
end
