defmodule LangchainPrompt.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/exfoundry/langchain_prompt"

  def project do
    [
      app: :langchain_prompt,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "LangchainPrompt",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp aliases do
    [
      precommit: [
        "compile --warning-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "test"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:langchain, "~> 0.7"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Convenience wrapper around langchain with a structured prompt contract and post-processing."
  end

  defp package do
    [
      maintainers: ["Elias Forge"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/langchain_prompt/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE usage-rules.md)
    ]
  end

  defp docs do
    [
      main: "LangchainPrompt",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
