defmodule Tackle.MulticonsumerTest do
  use ExUnit.Case, async: false

  defmodule MulticonsumerExample do
    require Logger

    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "example_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      Logger.info("Handled!")
    end
  end

  defmodule MulticonsumerExample2 do
    require Logger

    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "example_service2",
      service_per_exchange: true,
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      Logger.info("Handled!")
    end
  end

  defmodule MulticonsumerExampleBeta do
    require Logger

    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "#{System.get_env("A")}.example_beta_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      Logger.info("Handled!")
    end
  end

  defmodule MulticonsumerExampleBeta2 do
    require Logger

    use Tackle.Multiconsumer,
      url: "amqp://rabbitmq:5672",
      service: "#{System.get_env("A")}.example_beta_service2",
      service_per_exchange: true,
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(_message) do
      Logger.info("Handled!")
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
        :"Elixir.Tackle.MulticonsumerTest.MulticonsumerExampleBeta2.exchange-1.key1",
        :"Elixir.Tackle.MulticonsumerTest.MulticonsumerExample.exchange-1.key1",
        :"Elixir.Tackle.MulticonsumerTest.MulticonsumerExample2.exchange-1.key1"
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

  describe "MulticonsumerWithMultipleHandlers and dynamic queue names" do
    defmodule MulticonsumerWithDynamicQueueName do
      use Tackle.Multiconsumer,
        url: "amqp://rabbitmq:5672",
        service: "MulticonsumerWithMultipleHandlersService",
        routes: [
          {"MulticonsumerWithMultipleHandlersExchange", "routing.key1", :first_handler},
          {"MulticonsumerWithMultipleHandlersExchange", "routing.key2", :second_handler},
          {"MulticonsumerWithMultipleHandlersExchange", "routing.key3", :third_handler}
        ],
        queue: :dynamic,
        queue_opts: [
          auto_delete: true,
          exclusive: true
        ]

      def first_handler(_message) do
        send(:checker, "first handler fired")
      end

      def second_handler(_message) do
        send(:checker, "second handler fired")
      end

      def third_handler(_message) do
        send(:checker, "third handler fired")
      end
    end

    test "works like a broadcast" do
      Process.register(self(), :checker)

      {:ok, _pid} =
        MulticonsumerWithDynamicQueueName.start_link(process_name: {:global, make_ref()})

      {:ok, _pid} =
        MulticonsumerWithDynamicQueueName.start_link(process_name: {:global, make_ref()})

      {:ok, c} = Tackle.Connection.open(:publisher, "amqp://rabbitmq:5672")
      channel = Tackle.Channel.create(c)
      exchange1 = Tackle.Exchange.create(channel, "MulticonsumerWithMultipleHandlersExchange")
      exchange2 = Tackle.Exchange.create(channel, "Exchange2")

      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key1")
      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key1")

      assert_receive "first handler fired", 1000
      assert_receive "first handler fired", 1000
      refute_receive "first handler fired", 1000
      refute_receive "second handler fired", 1000
      refute_receive "third handler fired", 1000

      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key2")
      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key2")

      assert_receive "second handler fired", 1000
      assert_receive "second handler fired", 1000
      refute_receive "first handler fired", 1000
      refute_receive "second handler fired", 1000
      refute_receive "third handler fired", 1000

      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key3")
      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key3")

      assert_receive "third handler fired", 1000
      assert_receive "third handler fired", 1000
      refute_receive "first handler fired", 1000
      refute_receive "second handler fired", 1000
      refute_receive "third handler fired", 1000
    end
  end

  describe "Multiconsumer with service per exchange" do
    defmodule MulticonsumerWithServicePerExchange do
      use Tackle.Multiconsumer,
        url: "amqp://rabbitmq:5672",
        service: "MulticonsumerWithSerivcePerExchangeService",
        service_per_exchange: true,
        routes: [
          {"Exchange1", "routing.key4", :first_handler},
          {"Exchange2", "routing.key4", :second_handler}
        ]

      def first_handler(_message) do
        send(:checker, "first handler fired")
      end

      def second_handler(_message) do
        send(:checker, "second handler fired")
      end
    end

    test "one message should be process by one handler" do
      Process.register(self(), :checker)

      {:ok, _pid} =
        MulticonsumerWithServicePerExchange.start_link(process_name: {:global, make_ref()})

      {:ok, _pid} =
        MulticonsumerWithServicePerExchange.start_link(process_name: {:global, make_ref()})

      {:ok, c} = Tackle.Connection.open(:publisher, "amqp://rabbitmq:5672")
      channel = Tackle.Channel.create(c)
      exchange1 = Tackle.Exchange.create(channel, "Exchange1")
      exchange2 = Tackle.Exchange.create(channel, "Exchange2")

      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key4")
      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key4")
      Tackle.Exchange.publish(channel, exchange1, "HELLO!", "routing.key4")

      assert_receive "first handler fired", 1000
      assert_receive "first handler fired", 1000
      assert_receive "first handler fired", 1000
      refute_receive "second handler fired", 1000
      refute_receive "first handler fired", 1000

      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key4")
      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key4")
      Tackle.Exchange.publish(channel, exchange2, "HELLO!", "routing.key4")

      assert_receive "second handler fired", 1000
      assert_receive "second handler fired", 1000
      assert_receive "second handler fired", 1000
      refute_receive "first handler fired", 1000
      refute_receive "second handler fired", 1000
    end
  end
end
