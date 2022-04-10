defmodule Statux.MixProject do
  use Mix.Project

  @version "0.1.4"

  def project do
    [
      app: :statux,
      version: @version,
      elixir: "~> 1.10",
      description: "Tracks values and derives status and status transitions",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Statux",
      source_url: "https://github.com/larshei/statux",
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
      {:benchee, "~> 1.0", only: :dev, runtime: false},
      {:dialyzex, "~> 1.3.0", only: :dev},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:struct_access, "~> 1.1"},
      {:timex, "~> 3.7"},
      {:typed_struct, "~> 0.2"},
    ]
  end

    ### --
  # all configuration required by ex_doc to configure the generation of documents
  ### --
  defp docs do
    [
      main: "what_is_statux",
      source_ref: "#{@version}",
      source_url: "https://github.com/larshei/statux",
      extra_section: "GUIDES",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules(),
    ]
  end


  defp extras do
    [
      "guides/introduction/what_is_statux.md",
      "guides/introduction/installation.md",
      "guides/introduction/getting_started.md",
      "guides/introduction/tracking.md",
      "guides/rule_set/options.md",
      "guides/rule_set/multiple_rule_sets.md",
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      "Rule Sets": ~r/guides\/rule_set\/.?/,
    ]
  end

  defp groups_for_modules do
    [
      "Main API": [
        Statux,
      ],
      Models: [
        Statux.Models.EntityStatus,
        Statux.Models.Status,
        Statux.Models.TrackerState,
        Statux.Models.TrackingData,
      ],
      Internals: [
        Statux.Constraints,
        Statux.Entities,
        Statux.RuleSet,
        Statux.RuleSet.Parser,
        Statux.Tracker,
        Statux.Transitions,
        Statux.ValueRules,
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Lars Heinrichs"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/larshei/statux"},
      files:
        ~w(lib) ++
          ~w(CHANGELOG.md LICENSE.md mix.exs rule_set.json README.md)
    ]
  end
end
