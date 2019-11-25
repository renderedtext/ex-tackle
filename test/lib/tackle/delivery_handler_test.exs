defmodule Tackle.DeliveryHandlerTest do
  use ExSpec

  # This is needed for delivery_handler to be generated.
  defmodule TestConsumer do
    require Logger

    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "ex-tackle.test-exchange",
      routing_key: "test-messages",
      service: "ex-tackle.test-service"

    def handle_message(_message) do
      Logger.debug("here")
    end
  end

  describe "delivery" do
    it "consume pass" do
      assert :ok ==
               TestConsumer.delivery_handler(
                 fn -> :ok end,
                 fn _a -> :error end
               )
    end

    it "consume generates arithmetic exception" do
      bad_function = fn ->
        Code.eval_quoted(quote do: 1 / 0)
      end

      assert :badarith ==
               TestConsumer.delivery_handler(bad_function, fn reason -> reason end)
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

    it "can enforce retry with an throw(:retry)" do
      assert :retry_requested ==
               TestConsumer.delivery_handler(fn -> throw(:retry) end, fn {reason, _stacktrace} ->
                 reason
               end)
    end

    it "can enforce retry with an throw(:retry, reason)" do
      assert {:error, :error_reason} ==
               TestConsumer.delivery_handler(
                 fn -> throw({:retry, {:error, :error_reason}}) end,
                 fn {reason, _stacktrace} ->
                   reason
                 end
               )
    end
  end
end
