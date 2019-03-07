defmodule Paracusia.Mixfile do
  use Mix.Project

  def project do
    [
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: [test: "test --no-start"],
      app: :paracusia,
      version: "0.2.10",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "MPD client library",
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [applications: [:logger], mod: {Paracusia, []}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19.3", only: :dev},
      {:excoveralls, "~> 0.10.6", only: :test},
      {:jason, "~> 1.1", optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Fabian Muscariello"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nroi/paracusia"}
    ]
  end
end
