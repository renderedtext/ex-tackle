defmodule Tackle.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tackle,
      version: "0.2.3",
      elixir: "~> 1.11",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Tackle, []}
    ]
  end

  defp deps do
    [
      {:amqp, "~> 3.2"},
      {:junit_formatter, "~> 3.3", only: [:test]}
    ]
  end
end
