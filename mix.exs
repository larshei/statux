defmodule StatusTracker.MixProject do
  use Mix.Project

  def project do
    [
      app: :status_tracker,
      version: "0.1.0",
      elixir: "~> 1.13",
      description: "Tracks values and derives status and status transitions",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:timex, "~> 3.7.6"},
      {:phoenix_pubsub, "~> 2.0"},
      {:jason, "~> 1.3.0"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:benchee, "~> 1.0.1", only: :dev, runtime: false},
    ]
  end

  defp package() do
    [
    licenses: [],
    links: %{},
    ]
  end
end
