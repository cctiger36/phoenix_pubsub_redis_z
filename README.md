[![Actions Status](https://github.com/cctiger36/phoenix_pubsub_redis_z/workflows/test/badge.svg)](https://github.com/cctiger36/phoenix_pubsub_redis_z/actions)
[![Coverage Status](https://coveralls.io/repos/github/cctiger36/phoenix_pubsub_redis_z/badge.svg?branch=master)](https://coveralls.io/github/cctiger36/phoenix_pubsub_redis_z?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_pubsub_redis_z.svg)](https://hex.pm/packages/phoenix_pubsub_redis_z)

# PhoenixPubsubRedisZ

Yet another Redis PubSub adapter for Phoenix. Supports sharding across multiple redis nodes.

## Why made another one?

The original [phoenix_pubsub_redis](https://github.com/phoenixframework/phoenix_pubsub_redis) will subscribe to a single topic (the namespace) from all Phoenix nodes. Whatever you publish, the message will be sent to all your nodes. So when you have a large number of nodes, it will become very inefficient. The single Redis instance will become the bottleneck. And because there is only a single topic, it is impossible to scale it.

So we have made this adapter, which will subscribe to the specific topic of the Phoenix channel when creating it, and unsubscribe to that topic after the Phoenix channel is shut down. If you publish something to a topic, the message will only be sent to the nodes which have the Phoenix channels subscribing to that topic.

Also, we have added a feature for sharding, based on the topics. You can simply do a load balancing by adding extra Redis instances.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:phoenix_pubsub_redis_z, "~> 0.4"}
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
| `:local_pool_size`        | The pool size of local subscription server                             | 2        |
| `:publisher_pool_size`    | The pool size of redis publish connections for each redis-server       | 8        |
| `:compression_level`      | Compression level applied to serialized terms (0 - none, 9 - highest)  | 0        |
