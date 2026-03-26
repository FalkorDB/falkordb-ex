defmodule FalkorDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :falkordb,
      name: "falkordb",
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/FalkorDB/falkordb-ex",
      docs: [main: "readme", extras: ["README.md"]],
      aliases: aliases(),
      deps: deps(),
      description: "FalkorDB client for Elixir built on top of Redix",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {FalkorDB.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:redix, "~> 1.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs mix.lock README.md LICENSE examples),
      licenses: ["MIT"],
      maintainers: ["FalkorDB Team"],
      links: %{
        "GitHub" => "https://github.com/FalkorDB/falkordb-ex",
        "FalkorDB" => "https://github.com/FalkorDB/FalkorDB"
      }
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "credo --strict",
        "test"
      ]
    ]
  end
end
