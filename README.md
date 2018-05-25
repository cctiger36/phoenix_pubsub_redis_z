# PhoenixPubsubRedisZ

Yet another Redis PubSub adapter for Phoenix. Supports sharding across multiple redis nodes.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:phoenix_pubsub_redis_z, "~> 0.1.0"}
  ]
end
```

## Usage

Add it to your Endpoint's config:
```elixir
config :my_app, MyApp.Endpoint,
  pubsub: [
    name: MyApp.PubSub,
    adapter: Phoenix.PubSub.RedisZ,
    redis_urls: ["redis://redis01:6379/0", "redis://redis02:6379/0"]
  ]
```

### Options

| Option                    | Description                                                            | Default  |
| :------------------------ | :--------------------------------------------------------------------- | :------- |
| `:name`                   | The required name to register the PubSub processes, ie: `MyApp.PubSub` |          |
| `:redis_urls`             | The required redis-server URL list                                     |          |
| `:node_name`              | The name of the node                                                   | `node()` |
| `:pool_size`              | The pool size of local pubsub server                                   | 1        |
| `:publisher_pool_size`    | The pool size of redis publish connections for each redis-server       | 8        |
| `:publisher_max_overflow` | Maximum number of publish connections created if pool is empty         | 0        |
