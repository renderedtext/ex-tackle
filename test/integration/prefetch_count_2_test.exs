defmodule Tackle.ParallelMessageHandling_2_Test do
  use ExSpec

  alias Support

  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-prefetch-2-exchange",
      routing_key: "prefetch",
      service: "prefetch-count-service",
      prefetch_count: 2

    def handle_message(message) do
      "#PID" <> spid = message
      sup = spid |> String.to_charlist |> :erlang.list_to_pid
      Task.Supervisor.async_nolink(sup, fn-> :timer.sleep :infinity end)
      receive do _msg -> nil end
    end
  end

  @publish_options %{
    url: "amqp://localhost",
    exchange: "test-prefetch-2-exchange",
    routing_key: "prefetch",
  }

  setup do
    {:ok, _} = TestConsumer.start_link

    {:ok, sup} = Task.Supervisor.start_link()
    |> IO.inspect

    :timer.sleep(1000)

    {:ok, [sup: sup]}
  end

  describe "parallel message handling" do
    it "handles messages in pairs", context do
      sup = context[:sup]
      Tackle.publish(sup |> inspect, @publish_options)
      Tackle.publish(sup |> inspect, @publish_options)
      Tackle.publish(sup |> inspect, @publish_options)
      Tackle.publish(sup |> inspect, @publish_options)

      :timer.sleep(1000)

      assert Task.Supervisor.children(sup) |> Enum.count == 2
      Task.Supervisor.children(sup)
      |> Enum.each(fn pid -> Task.Supervisor.terminate_child(sup, pid) end)

      :timer.sleep(1000)

      assert Task.Supervisor.children(sup) |> Enum.count == 2
      Task.Supervisor.children(sup)
      |> Enum.each(fn pid -> Task.Supervisor.terminate_child(sup, pid) end)

      :timer.sleep(1000)

      assert Task.Supervisor.children(sup) |> Enum.count == 0
    end
  end
end
