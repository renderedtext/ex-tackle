defmodule DiscardTest do
  use ExSpec

  defmodule BrokenConsumer do
    use Tackle.Consumer,
      url: "amqp://localhost",
      exchange: "broken-exchange",
      routing_key: "broken-messages",
      queue: "broken-consumer",
      retry_limit: 10,
      retry_delay: 1

    def handle_message(message) do
      IO.puts "Here! " <> message
      raise "Giving up"
    end
  end

  @broken_publish_options %{
    url: "amqp://localhost",
    exchange: "broken-exchange",
    routing_key: "broken-messages",
  }

  ExSpec.describe "discard message after retry limit is reached" do
    it "discards message after 10 retries" do
       Support.purge_queue("broken-consumer")
       Support.purge_queue("broken-consumer_dead_letters")

       {:ok, consumer} = BrokenConsumer.start_link
       Tackle.publish("Hi!", @broken_publish_options)

       # Wait for 10 retries and for message discarding
       :timer.sleep(12 * 1000)
       GenServer.stop(consumer)

       {queue_messages, dl_queue_messages} = {
         Support.queue_status("broken-consumer").message_count,
         Support.queue_status("broken-consumer_dead_letters").message_count
       }

       assert {queue_messages, dl_queue_messages} == {0, 0}
    end
  end
end
