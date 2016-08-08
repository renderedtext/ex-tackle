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

  @queue_url "http://localhost:15672/api/queues/%2f/broken-consumer"
  @dl_queue_url "http://localhost:15672/api/queues/%2f/broken-consumer_dead_letters"

  ExSpec.describe "discard message after " do
    it "discards message after 10 tries" do

      # Rabbitmq managment plugin should be enabled
      # 'rabbitmq-plugins enable rabbitmq_management'
      
      HTTPotion.start
      # Reset queues
      HTTPotion.delete(@queue_url)
      HTTPotion.delete(@dl_queue_url)

      {:ok, consumer} = BrokenConsumer.start_link
      Tackle.publish("Hi!", @broken_publish_options)

      # Wait for 10 retries and for message discarding
      :timer.sleep(15 * 1000)
      GenServer.stop(consumer)

      # Get queues info
      opts = [basic_auth: {"guest", "guest"}]
      response = HTTPotion.get(@queue_url, opts)
      response_dl = HTTPotion.get(@dl_queue_url, opts)
      # Decode response into map
      {:ok, body} = Poison.decode(response.body)
      {:ok, body_dl} = Poison.decode(response_dl.body)

      assert {body["messages"], body_dl["messages"]} == {0, 0}
    end
  end
end
