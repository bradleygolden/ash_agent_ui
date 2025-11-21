defmodule AshAgentUi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_agent_ui,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AshAgentUi.Application, []},
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:jason, "~> 1.2"},
      {:igniter, "~> 0.3"},
      {:esbuild, "~> 0.8", only: :dev},
      {:tailwind, "~> 0.2", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: [:dev, :test], runtime: false}
    ] ++
      ash_agent_dep()
  end

  defp ash_agent_dep do
    if File.exists?("../ash_agent/mix.exs") do
      [{:ash_agent, path: "../ash_agent"}]
    else
      [{:ash_agent, github: "bradleygolden/ash_agent"}]
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind ash_agent_ui", "esbuild ash_agent_ui"],
      "assets.deploy": ["tailwind ash_agent_ui --minify", "esbuild ash_agent_ui --minify", "phx.digest"],
      precommit: [
        "deps.get",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format github",
        "docs --warnings-as-errors",
        "test --warnings-as-errors"
      ]
    ]
  end
end
