defmodule Tackle.Mixfile do
  use Mix.Project

  def project do
    [app: :tackle,
     version: "0.1.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end
  def application do
    [ applications: [:logger, :amqp],
      mod: {Tackle, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 0.1.4"},
      {:ex_spec, "~> 1.0.0", only: :test},
      {:poison, "~> 2.0", only: :test},
      {:httpotion, "~> 3.0.0", only: :test}
    ]
  end
end
