defmodule ApiBattle.MixProject do
  use Mix.Project

  def project do
    [
      app: :apibattle,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [apibattle: [include_executables_for: [:unix]]]
    ]
  end

  def application do
    [
      mod: {ApiBattle.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.5"},
      {:bandit, "~> 1.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.20"},
      {:jason, "~> 1.4"}
    ]
  end
end
