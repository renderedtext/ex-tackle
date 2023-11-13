defmodule Tackle.Util do
  def parse_exchange(exchange) do
    case exchange do
      {:direct, _name} = exchange -> exchange
      {:topic, _name} = exchange -> exchange
      {:fanout, _name} = exchange -> exchange
      name -> {:direct, name}
    end
  end

  def cleanup(:default, connection, channel) do
    AMQP.Channel.close(channel)
    AMQP.Connection.close(connection)
  end

  def cleanup(_, _, channel) do
    AMQP.Channel.close(channel)
  end
end
