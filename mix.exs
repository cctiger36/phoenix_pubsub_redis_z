defmodule PhoenixPubsubRedisZ.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_pubsub_redis_z,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:phoenix_pubsub, "~> 1.0"},
      {:poolboy, "~> 1.5 or ~> 1.6"},
      {:redix, "~> 0.6.1"},
      {:redix_pubsub, "~> 0.4.2"}
    ]
  end
end
