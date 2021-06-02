defmodule Tackle.DeliveryHandlerTest do
  use ExSpec

  # This is needed for delivery_handler to be generated.
  defmodule TestConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "test-exchange",
      routing_key: "test-messages",
      service: "test-service"

    def handle_message(_) do
      IO.puts("here")
    end
  end

  describe "delivery" do
    it "consume pass" do
      assert :ok ==
               TestConsumer.delivery_handler(
                 fn -> :ok end,
                 fn _ -> :error end
               )
    end

    it "consume generates arithmetic exception" do
      assert :badarith ==
               TestConsumer.delivery_handler(fn -> :asd - 1 end, fn reason ->
                 reason
               end)
               |> elem(0)
    end

    it "consume raises" do
      assert %RuntimeError{message: "foo"} ==
               TestConsumer.delivery_handler(fn -> raise "foo" end, fn reason -> reason end)
               |> elem(0)
    end

    it "consume throws" do
      assert {:nocatch, {:error, 12}} ==
               TestConsumer.delivery_handler(fn -> throw({:error, 12}) end, fn reason ->
                 reason
               end)
               |> elem(0)
    end

    it "consume signals" do
      assert :foo ==
               TestConsumer.delivery_handler(fn -> Process.exit(self(), :foo) end, fn reason ->
                 reason
               end)
    end
  end
end
