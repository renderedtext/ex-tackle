defmodule Tackle.MulticonsumerTest do
  use ExUnit.Case, async: false

  defmodule MulticonsumerExample do
    use Tackle.Multiconsumer,
      url: "amqp://localhost",
      service: "example_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(message) do
      IO.puts("Handled!")
    end
  end

  defmodule MulticonsumerExampleBeta do
    use Tackle.Multiconsumer,
      url: "amqp://localhost",
      service: "#{System.get_env("A")}.example_beta_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(message) do
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

  test "successfully starts multiconsumers" do
    import Supervisor.Spec
    opts = [strategy: :one_for_one, name: Front.Supervisor]

    Supervisor.start_link(
      [worker(MulticonsumerExample, []), worker(MulticonsumerExampleBeta, [])],
      opts
    )
  end
end
