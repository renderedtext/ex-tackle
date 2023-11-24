defmodule Tackle.Util do
  def parse_exchange(exchange) do
    case exchange do
      {:direct, _name} = exchange -> exchange
      {:topic, _name} = exchange -> exchange
      {:fanout, _name} = exchange -> exchange
      name -> {:direct, name}
    end
  end
end
