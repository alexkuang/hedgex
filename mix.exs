defmodule Hedgex.MixProject do
  use Mix.Project

  def project do
    [
      app: :hedgex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer_settings()
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
      {:req, "~> 0.5.0"},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer_settings do
    [
      plt_file: {:no_warn, "priv/plts/hedgex.plt"},
      plt_add_apps: [:mix]
    ]
  end
end
