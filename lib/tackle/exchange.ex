defmodule Tackle.Exchange do
  use AMQP
  require Logger

  def create_exchange_for_service(channel, service_name) do
    Logger.info "Creating exchange for #{service_name}"

    Exchange.direct(channel, service_name, durable: true)
  end

  def bind(channel, service_exchange, remote_exchange, routing_key) do
    Logger.info "Bindind '#{service_exchange}' to '#{remote_exchange}' with '#{routing_key}'"

    Exchange.bind(channel, service_name, remote_exchange, routing_key: routing_key)
  end

end
