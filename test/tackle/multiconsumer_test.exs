defmodule Tackle.MulticonsumerTest do
  use ExUnit.Case, async: false

  defmodule MulticonsumerExample do
    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "example_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      IO.puts("Handled!")
    end
  end

  defmodule MulticonsumerExampleBeta do
    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "#{System.get_env("A")}.example_beta_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      IO.puts("Handled!")
    end
  end

  test "inspect modules" do
    defined_consumer_modules =
      :code.all_loaded()
      |> Enum.map(fn {mod, _} -> mod end)
      |> Enum.filter(fn module -> String.contains?(Atom.to_string(module), "exchange-1.key1") end)
      |> Enum.sort()

    expected_consumer_modules =
      [
        :"Elixir.Tackle.MulticonsumerTest.MulticonsumerExampleBeta.exchange-1.key1",
        :"Elixir.Tackle.MulticonsumerTest.MulticonsumerExample.exchange-1.key1"
      ]
      |> Enum.sort()

    assert defined_consumer_modules == expected_consumer_modules
  end

  test "successfully starts multiconsumers the old way" do
    import Supervisor.Spec
    opts = [strategy: :one_for_one, name: Front.Supervisor]

    Supervisor.start_link(
      [worker(MulticonsumerExample, []), worker(MulticonsumerExampleBeta, [])],
      opts
    )
  end

  test "successfully starts multiconsumers" do
    opts = [strategy: :one_for_one, name: Front.Supervisor]

    Supervisor.start_link(
      [MulticonsumerExample, MulticonsumerExampleBeta],
      opts
    )
  end

  describe "MulticonsumerWithDynamicQueueName" do
    defmodule MulticonsumerWithDynamicQueueName do
      use Tackle.Multiconsumer,
        url: "amqp://rabbitmq:5672",
        service: "example_service",
        routes: [
          {{:topic, "exchange-2"}, "routing.key.*", :first_handler},
          {{:topic, "exchange-2"}, "routing.#", :second_handler}
        ],
        queue_name: :dynamic

      def first_handler(_message) do
        send(:checker, "first handler fired")
      end

      def second_handler(message) do
        send(:checker, "second handler fired")
      end
    end

    test "works" do
      Process.register(self(), :checker)
      MulticonsumerWithDynamicQueueName.start_link([])

      Tackle.publish("HELLO!",
        url: "amqp://rabbitmq:5672",
        exchange: {:topic, "exchange-2"},
        routing_key: "routing.key.foo"
      )

      assert_receive "first handler fired", 1000
      assert_receive "second handler fired", 1000
    end
  end
end
