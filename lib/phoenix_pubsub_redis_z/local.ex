defmodule Phoenix.PubSub.RedisZ.Local do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{GC, LocalSupervisor, RedisDispatcher}

  require Logger

  use GenServer

  @type t :: %{
          monitors: %{pid => reference},
          gc: atom
        }

  @spec local_name(atom, non_neg_integer) :: atom
  def local_name(pubsub_name, shard) do
    Module.concat(["#{pubsub_name}.RedisZ.Local#{shard}"])
  end

  @spec gc_name(atom, non_neg_integer) :: atom
  def gc_name(pubsub_name, shard) do
    Module.concat(["#{pubsub_name}.RedisZ.GC#{shard}"])
  end

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts) do
    Logger.info("Starts pubsub_redis_z local: #{opts[:server_name]}")
    GenServer.start_link(__MODULE__, opts, name: opts[:server_name])
  end

  @impl GenServer
  def init(opts) do
    :ets.new(opts[:server_name], [
      :duplicate_bag,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(opts[:gc], [
      :duplicate_bag,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.flag(:trap_exit, true)
    {:ok, %{monitors: %{}, gc: opts[:gc]}}
  end

  @spec subscribe(atom, pid, binary) :: :ok
  def subscribe(pubsub_name, pid, topic)
      when is_atom(pubsub_name) do
    {:ok, {_adapter, adapter_name}} = Registry.meta(pubsub_name, :pubsub)

    {local, gc} =
      pid
      |> :erlang.phash2(pool_size(adapter_name))
      |> pools_for_shard(pubsub_name)

    :ok = GenServer.call(local, {:monitor, pid})

    if :ets.match_object(local, {topic, :_}, 1) == :"$end_of_table" do
      :ok = RedisDispatcher.subscribe(pubsub_name, pid, topic)
    end

    true = :ets.insert(gc, {pid, topic})
    true = :ets.insert(local, {topic, pid})

    :ok
  end

  @spec unsubscribe(atom, pid, binary) :: :ok
  def unsubscribe(pubsub_name, pid, topic)
      when is_atom(pubsub_name) do
    {:ok, {_adapter, adapter_name}} = Registry.meta(pubsub_name, :pubsub)

    {local, gc} =
      pid
      |> :erlang.phash2(pool_size(adapter_name))
      |> pools_for_shard(pubsub_name)

    true = :ets.match_delete(gc, {pid, topic})
    true = :ets.match_delete(local, {topic, pid})

    if :ets.match_object(local, {topic, :_}, 1) == :"$end_of_table" do
      :ok = RedisDispatcher.unsubscribe(pubsub_name, pid, topic)
    end

    case :ets.select_count(gc, [{{pid, :_}, [], [true]}]) do
      0 -> :ok = GenServer.call(local, {:demonitor, pid})
      _ -> :ok
    end
  end

  def subscribers(pubsub_name, topic, shard) when is_atom(pubsub_name) do
    try do
      shard
      |> local_for_shard(pubsub_name)
      |> :ets.lookup_element(topic, 2)
    catch
      :error, :badarg -> []
    end
  end

  @impl GenServer
  def handle_call({:monitor, pid}, _from, state) do
    {:reply, :ok, put_new_monitor(state, pid)}
  end

  def handle_call({:demonitor, pid}, _from, state) do
    {:reply, :ok, drop_monitor(state, pid)}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    GC.down(state.gc, pid)
    {:noreply, drop_monitor(state, pid)}
  end

  def handle_info(_, state), do: {:noreply, state}

  @spec pools_for_shard(non_neg_integer, atom) :: {atom, atom}
  defp pools_for_shard(shard, pubsub_name) do
    table_name = LocalSupervisor.pools_table_name(pubsub_name)
    {_, _} = servers = :ets.lookup_element(table_name, shard, 2)
    servers
  end

  @spec put_new_monitor(t, pid) :: t
  defp put_new_monitor(%{monitors: monitors} = state, pid) do
    case Map.fetch(monitors, pid) do
      {:ok, _ref} -> state
      :error -> %{state | monitors: Map.put(monitors, pid, Process.monitor(pid))}
    end
  end

  @spec drop_monitor(t, pid) :: t
  defp drop_monitor(%{monitors: monitors} = state, pid) do
    case Map.fetch(monitors, pid) do
      {:ok, ref} ->
        Process.demonitor(ref)
        %{state | monitors: Map.delete(monitors, pid)}

      :error ->
        state
    end
  end

  @spec pool_size(atom) :: pos_integer
  defp pool_size(adapter_name) do
    :ets.lookup_element(adapter_name, :local_pool_size, 2)
  end

  @spec local_for_shard(non_neg_integer, atom) :: atom
  defp local_for_shard(shard, pubsub_name) do
    {local_server, _gc_server} = pools_for_shard(shard, pubsub_name)
    local_server
  end
end
