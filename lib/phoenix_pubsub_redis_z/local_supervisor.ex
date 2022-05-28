defmodule Phoenix.PubSub.RedisZ.LocalSupervisor do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{GC, Local}

  use Supervisor

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    pubsub_name = opts[:pubsub_name]
    table_name = pools_table_name(pubsub_name)
    :ets.new(table_name, [:set, :named_table, read_concurrency: true])

    children =
      for shard <- 0..(opts[:pool_size] - 1) do
        local_shard_name = Local.local_name(pubsub_name, shard)
        gc_shard_name = Local.gc_name(pubsub_name, shard)
        true = :ets.insert(table_name, {shard, {local_shard_name, gc_shard_name}})

        shard_children = [
          {GC,
           [server_name: gc_shard_name, local_name: local_shard_name, pubsub_name: pubsub_name]},
          {Local, [server_name: local_shard_name, gc: gc_shard_name]}
        ]

        %{
          id: {__MODULE__, shard},
          start: {Supervisor, :start_link, [shard_children, [strategy: :one_for_all]]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec pools_table_name(atom) :: atom
  def pools_table_name(pubsub_name) do
    :"#{pubsub_name}.LocalPool"
  end
end
