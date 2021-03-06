defmodule Morbo.MixProject do
  use Mix.Project

  def project do
    [
      app: :morbo,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.11.1", only: :test},
      {:hackney, "~> 1.15", only: :test},
      {:eyepatch, git: "https://github.com/nroi/eyepatch.git", tag: "v0.1.11", only: :test}
    ]
  end
end
