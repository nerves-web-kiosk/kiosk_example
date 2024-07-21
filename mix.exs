defmodule KioskExample.MixProject do
  use Mix.Project

  @app :kiosk_example
  @version "0.1.0"
  @all_targets [:rpi4, :rpi5]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: "~> 1.13"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :os_mon],
      mod: {KioskExample.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.0"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
      {:nerves_weston,
       github: "fhunleth/nerves_weston",
       ref: "7a14e51a23d3b63333d594f20515874496cf6584",
       targets: @all_targets},
      {:nerves_cog,
       github: "coop/nerves_cog",
       ref: "3afb3ec73c67fb050d296b141476f45eab420a5c",
       targets: @all_targets},
      {:example_ui, path: "../example_ui", targets: @all_targets, env: Mix.env()},

      # Dependencies for specific targets
      # NOTE: It's generally low risk and recommended to follow minor version
      # bumps to Nerves systems. Since these include Linux kernel and Erlang
      # version updates, please review their release notes in case
      # changes to your application are needed.
      {:kiosk_system_rpi4, "~> 0.1.0", runtime: false, targets: :rpi4},
      {:kiosk_system_rpi5, "~> 0.1.0", runtime: false, targets: :rpi5}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end
