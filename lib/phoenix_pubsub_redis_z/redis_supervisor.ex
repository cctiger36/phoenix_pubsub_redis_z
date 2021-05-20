defmodule Phoenix.PubSub.RedisZ.RedisSupervisor do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{RedisPublisher, RedisSubscriber}

  use Supervisor

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(options), do: Supervisor.start_link(__MODULE__, options)

  @spec init(keyword) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(options) do
    pubsub_server = options[:pubsub_server]

    children =
      options[:redises]
      |> Enum.with_index()
      |> Enum.map(fn {redis_options, shard} ->
        subscriber_name = RedisSubscriber.server_name(pubsub_server, shard)
        publisher_name = RedisPublisher.pool_name(pubsub_server, shard)
        subscriber_options = Keyword.put(options, :redis_options, redis_options)

        publisher_pool_options = [
          name: {:local, publisher_name},
          worker_module: Redix,
          size: options[:publisher_pool_size],
          max_overflow: options[:publisher_max_overflow]
        ]

        shard_children = [
          {RedisSubscriber, [subscriber_name, subscriber_options]},
          :poolboy.child_spec(publisher_name, publisher_pool_options, redis_options)
        ]

        Supervisor.child_spec(
          {Supervisor, [shard_children, [strategy: :one_for_all]]},
          id: {__MODULE__, shard}
        )
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
