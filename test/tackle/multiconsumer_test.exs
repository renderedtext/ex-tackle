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
      service: "example_beta_service",
      routes: [
        {"exchange-1", "key1", :handler}
      ]

    def handler(message) do
      IO.puts("Handled!")
    end
  end

  test "successfully starts multiconsumers" do
    import Supervisor.Spec
    opts = [strategy: :one_for_one, name: Front.Supervisor]
    Supervisor.start_link([worker(MulticonsumerExample, [])], opts)
  end
end
