defmodule Tackle.Util do
  def parse_exchange(exchange) do
    case exchange do
      {:direct, _name} = exchange -> exchange
      {:topic, _name} = exchange -> exchange
      {:fanout, _name} = exchange -> exchange
      name -> {:direct, name}
    end
  end

  def resolve_queue(queue, service_exchange_name) do
    case queue do
      nil -> service_exchange_name
      :dynamic -> unique_name(20)
      name -> name
    end
  end

  defp unique_name(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode32(padding: false)
  end
end
