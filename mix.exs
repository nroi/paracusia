defmodule Paracusia.Mixfile do
  use Mix.Project

  def project do
    [
     app: :paracusia,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package(),
     description: "MPD client library"
    ]
  end

  def application do
    [applications: [:logger],
     mod: {Paracusia, []}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev},
      {:distillery, "~> 0.10.0"}
    ]
  end

  defp package do
    [
     maintainers: ["Fabian Muscariello"],
     licenses: ["MIT"]
	 # TODO add github URL once it's available.
     # links: %{"GitHub" => "https://github.com/???",
     #         "Docs" => "http://???"}]
    ]
  end
end
