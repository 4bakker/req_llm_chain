defmodule ReqLLMChain.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :req_llm_chain,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req_llm, "~> 1.0-rc"},
      {:jason, "~> 1.4"},

      # Dev dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A lightweight conversation builder for ReqLLM, providing LangChain-style
    builder patterns, tool calling loops, and conversation state management.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/4bakker/req_llm_chain"
      }
    ]
  end

  defp docs do
    [
      main: "ReqLLMChain",
      extras: ["README.md"]
    ]
  end
end
