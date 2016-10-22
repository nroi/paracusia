defmodule Paracusia.Mixfile do
  use Mix.Project

  def project do
    [
     elixirc_paths: elixirc_paths(Mix.env),
     aliases: [test: "test --no-start"],
     app: :paracusia,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     description: "MPD client library",
     test_coverage: [tool: ExCoveralls],
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [applications: [:logger],
     mod: {Paracusia, []}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev},
      {:distillery, "~> 0.10.0"},
      {:excoveralls, "~> 0.5", only: :test}
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
