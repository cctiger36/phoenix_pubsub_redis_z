defmodule Phoenix.PubSub.RedisZ.RedisSupervisor do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{RedisPublisher, RedisSubscriber}

  use Supervisor

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(options), do: Supervisor.start_link(__MODULE__, options)

  @impl Supervisor
  def init(options) do
    pubsub_name = options[:pubsub_name]

    children =
      options[:redises]
      |> Enum.with_index()
      |> Enum.map(fn {redis_opts, shard} ->
        subscriber_name = RedisSubscriber.server_name(pubsub_name, shard)

        subscriber_options =
          options
          |> Keyword.put(:redis_opts, redis_opts)
          |> Keyword.put(:server_name, subscriber_name)

        publisher_name = RedisPublisher.pool_name(options[:adapter_name], shard)

        publisher_pool_opts = [
          name: {:local, publisher_name},
          worker_module: Redix,
          size: options[:publisher_pool_size]
        ]

        shard_children = [
          {RedisSubscriber, subscriber_options},
          :poolboy.child_spec(publisher_name, publisher_pool_opts, redis_opts)
        ]

        %{
          id: {__MODULE__, shard},
          start: {Supervisor, :start_link, [shard_children, [strategy: :one_for_all]]}
        }
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
