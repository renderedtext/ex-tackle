defmodule Tackle do
  require Logger

  def publish(message, options) do
    url = options[:url]
    exchange = options[:exchange]
    routing_key = options[:routing_key]
  end

end
