defmodule Phoenix.PubSub.RedisZ.LocalSupervisor do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ
  alias Phoenix.PubSub.RedisZ.{GC, Local, RedisDispatcher}

  use Supervisor

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(options), do: Supervisor.start_link(__MODULE__, options)

  @spec init(keyword) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init(options) do
    server = options[:server_name]
    ^server = :ets.new(server, [:set, :named_table, read_concurrency: true])

    true =
      :ets.insert(server, [
        {:subscribe, Local, [server, options[:pool_size], options[:redises_count]]},
        {:unsubscribe, Local, [server, options[:pool_size], options[:redises_count]]},
        {:broadcast, RedisDispatcher,
         [
           options[:fastlane],
           server,
           options[:pool_size],
           options[:redises_count],
           options[:node_ref]
         ]},
        {:direct_broadcast, RedisDispatcher,
         [
           options[:fastlane],
           server,
           options[:pool_size],
           options[:redises_count],
           options[:node_ref]
         ]},
        {:node_name, RedisZ, [options[:node_name]]}
      ])

    children =
      for shard <- 0..(options[:pool_size] - 1) do
        local_shard_name = Local.local_name(server, shard)
        gc_shard_name = Local.gc_name(server, shard)
        true = :ets.insert(server, {shard, {local_shard_name, gc_shard_name}})

        shard_children = [
          {GC, [gc_shard_name, local_shard_name, server, options[:redises_count]]},
          {Local, [local_shard_name, gc_shard_name]}
        ]

        Supervisor.child_spec(
          {Supervisor, [shard_children, [strategy: :one_for_all]]},
          id: {__MODULE__, shard}
        )
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
