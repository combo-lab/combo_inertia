defmodule Combo.Inertia.MixProject do
  use Mix.Project

  @version "0.2.0"
  @description "Provides Inertia integration for Combo."
  @source_url "https://github.com/combo-lab/combo_inertia"
  @changelog_url "https://github.com/combo-lab/combo_inertia/blob/v#{@version}/CHANGELOG.md"

  def project do
    [
      app: :combo_inertia,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: @description,
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    combo =
      if System.get_env("USE_LOCAL_DEPS"),
        do: {:combo, path: "../combo", override: true},
        else: {:combo, "~> 0.5"}

    [
      combo,
      {:plug, "~> 1.14"},
      {:floki, ">= 0.30.0", only: :test},
      {:nodejs, "~> 3.0"},
      {:ecto, ">= 3.0.0"},
      {:ex_check, ">= 0.0.0", only: [:dev], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      extras: ["README.md", "USER_GUIDE.md", "CHANGELOG.md", "LICENSE"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        Source: @source_url,
        Changelog: @changelog_url
      },
      files: ~w(
        lib/
        mix.exs
        README.md
        USER_GUIDE.md
        CHANGELOG.md
        LICENSE
      )
    ]
  end

  defp aliases do
    [
      publish: ["hex.publish", "tag"],
      tag: &tag_release/1
    ]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as v#{@version}")
    System.cmd("git", ["tag", "v#{@version}", "--message", "Release v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
