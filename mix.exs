defmodule PhoenixPubsubRedisZ.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_pubsub_redis_z,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      name: "PhoenixPubsubRedisZ",
      package: package(),
      source_url: "https://github.com/cctiger36/phoenix_pubsub_redis_z",
      homepage_url: "https://github.com/cctiger36/phoenix_pubsub_redis_z",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      dialyzer: [
        flags: [:no_undefined_callbacks],
        ignore_warnings: "dialyzer.ignore-warnings",
        remove_defaults: [:unknown]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
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
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:inner_cotton, "~> 0.3", only: [:dev, :test]},
      {:phoenix_pubsub, "~> 1.1"},
      {:poolboy, "~> 1.5 or ~> 1.6"},
      {:redix, "~> 0.6.1"},
      {:redix_pubsub, "~> 0.4.2"}
    ]
  end

  defp package do
    [
      files: ["LICENSE", "README.md", "mix.exs", "lib"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cctiger36/phoenix_pubsub_redis_z"},
      maintainers: ["cctiger36 <cctiger36@gmail.com>"],
      name: "phoenix_pubsub_redis_z"
    ]
  end

  defp description do
    "Yet another Redis PubSub adapter for Phoenix. Supports sharding across multiple redis nodes."
  end
end
