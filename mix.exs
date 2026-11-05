defmodule ExcessibilityStorybook.MixProject do
  use Mix.Project

  @source_url "https://github.com/lessthanseventy/excessibility_storybook"
  @version "0.1.0"

  def project do
    [
      app: :excessibility_storybook,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Accessibility tools inside phoenix_storybook: a contrast matrix for your theme, " <>
          "what each component sounds like to a screen reader, its focus order, and stress views.",
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"],
        assets: %{"docs/images" => "docs/images"},
        source_ref: "v#{@version}",
        source_url: @source_url
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
      {:phoenix_live_view, "~> 1.1"},
      # the Inspector renders variations with storybook's ComponentRenderer: checked on 1.4 and 1.5
      {:phoenix_storybook, "~> 1.4"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "priv/static", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      maintainers: ["Andrew Moore"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Excessibility" => "https://github.com/lessthanseventy/excessibility"
      }
    ]
  end
end
