defmodule Tackle.Util do
  def parse_exchange(exchange) do
    case exchange do
      {:direct, _name} = exchange -> exchange
      {:topic, _name} = exchange -> exchange
      {:fanout, _name} = exchange -> exchange
      name -> {:direct, name}
    end
  end

  def scrub_url(url) do
    url
    |> URI.parse()
    |> Map.put(:userinfo, nil)
    |> URI.to_string()
  end
end
