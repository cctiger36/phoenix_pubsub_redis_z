# PhoenixPubsubRedisZ

[![Build Status](https://travis-ci.org/cctiger36/phoenix_pubsub_redis_z.svg?branch=master)](https://travis-ci.org/cctiger36/phoenix_pubsub_redis_z)
[![Coverage Status](https://coveralls.io/repos/github/cctiger36/phoenix_pubsub_redis_z/badge.svg?branch=master)](https://coveralls.io/github/cctiger36/phoenix_pubsub_redis_z?branch=master)
[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_pubsub_redis_z.svg)](https://hex.pm/packages/phoenix_pubsub_redis_z)

Yet another Redis PubSub adapter for Phoenix. Supports sharding across multiple redis nodes.

## Why made another one?

The original [phoenix_pubsub_redis](https://github.com/phoenixframework/phoenix_pubsub_redis) will subscribe to the same topic (the namespace) from all the Phoenix nodes. So whatever you publish, the data will be sent to all of them. If there are hundreds of Phoenix nodes, the CPU usage and the network usage of the Redis will become incredibly high and impossible to scale it.

So we have made this adapter, which will subscribe to the specific topic of the Phoenix channel when it is creating, and unsubscribe to that topic after the Phoenix channel is shut down. If you publish something to a topic, the data will only be sent to the nodes which have the Phoenix channels subscribing to that topic.

Also, we have added a feature for sharding, base on the topics. You can simply do a load balancing by adding Redis nodes.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:phoenix_pubsub_redis_z, "~> 0.3.0"}
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
