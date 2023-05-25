defmodule Tackle.DeliveryHandlerTest do
  use ExUnit.Case, async: false

  # This is needed for delivery_handler to be generated.
  defmodule TestConsumer do
    require Logger

    use Tackle.Consumer,
      url: "amqp://rabbitmq:5672",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "test-service"

    def handle_message(_) do
      Logger.info("Received message")
    end
  end

  describe "delivery" do
    test "consume pass" do
      assert :ok ==
               TestConsumer.delivery_handler(
                 fn -> :ok end,
                 fn _ -> :error end
               )
    end

    test "consume generates arithmetic exception" do
      assert :badarith ==
               TestConsumer.delivery_handler(fn -> :asd - 1 end, fn reason ->
                 reason
               end)
               |> elem(0)
    end

    test "consume raises" do
      assert %RuntimeError{message: "foo"} ==
               TestConsumer.delivery_handler(fn -> raise "foo" end, fn reason -> reason end)
               |> elem(0)
    end

    test "consume throws" do
      assert {:nocatch, {:error, 12}} ==
               TestConsumer.delivery_handler(fn -> throw({:error, 12}) end, fn reason ->
                 reason
               end)
               |> elem(0)
    end

    test "consume signals" do
      assert :foo ==
               TestConsumer.delivery_handler(fn -> Process.exit(self(), :foo) end, fn reason ->
                 reason
               end)
    end
  end
end
