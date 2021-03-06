defmodule Phoenix.PubSub.RedisZ.Local do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{GC, RedisDispatcher}

  require Logger

  use GenServer

  @type t :: %{
          monitors: %{pid => reference},
          gc: atom
        }

  defdelegate broadcast(fastlane, pubsub_server, pool_size, from, topic, msg),
    to: Phoenix.PubSub.Local

  defdelegate handle_call(request, from, state), to: Phoenix.PubSub.Local
  defdelegate init(args), to: Phoenix.PubSub.Local
  defdelegate list(pubsub_server, shard), to: Phoenix.PubSub.Local
  defdelegate subscribers(pubsub_server, topic, shard), to: Phoenix.PubSub.Local
  defdelegate subscribers_with_fastlanes(pubsub_server, topic, shard), to: Phoenix.PubSub.Local
  defdelegate subscription(pubsub_server, pool_size, pid), to: Phoenix.PubSub.Local

  @spec start_link(atom, atom) :: GenServer.on_start()
  def start_link(server_name, gc_name) do
    Logger.info("Starts pubsub local: #{server_name}")
    GenServer.start_link(__MODULE__, {server_name, gc_name}, name: server_name)
  end

  @spec subscribe(atom, pos_integer, pos_integer, pid, binary, keyword) :: :ok
  def subscribe(pubsub_server, pool_size, redises_count, pid, topic, opts \\ [])
      when is_atom(pubsub_server) do
    {local, gc} =
      pid
      |> :erlang.phash2(pool_size)
      |> pools_for_shard(pubsub_server)

    :ok = GenServer.call(local, {:monitor, pid, opts})

    if :ets.match_object(local, {topic, :_}, 1) == :"$end_of_table" do
      :ok = RedisDispatcher.subscribe(pubsub_server, redises_count, pid, topic)
    end

    true = :ets.insert(gc, {pid, topic})
    true = :ets.insert(local, {topic, {pid, opts[:fastlane]}})

    :ok
  end

  @spec unsubscribe(atom, pos_integer, pos_integer, pid, binary) :: :ok
  def unsubscribe(pubsub_server, pool_size, redises_count, pid, topic)
      when is_atom(pubsub_server) do
    {local, gc} =
      pid
      |> :erlang.phash2(pool_size)
      |> pools_for_shard(pubsub_server)

    true = :ets.match_delete(gc, {pid, topic})
    true = :ets.match_delete(local, {topic, {pid, :_}})

    if :ets.match_object(local, {topic, :_}, 1) == :"$end_of_table" do
      :ok = RedisDispatcher.unsubscribe(pubsub_server, redises_count, pid, topic)
    end

    case :ets.select_count(gc, [{{pid, :_}, [], [true]}]) do
      0 -> :ok = GenServer.call(local, {:demonitor, pid})
      _ -> :ok
    end
  end

  @spec local_name(atom, non_neg_integer) :: atom
  def local_name(pubsub_server, shard) do
    Module.concat(["#{pubsub_server}.RedisZ.Local#{shard}"])
  end

  @spec gc_name(atom, non_neg_integer) :: atom
  def gc_name(pubsub_server, shard) do
    Module.concat(["#{pubsub_server}.RedisZ.GC#{shard}"])
  end

  @spec handle_info(term, t) :: {:noreply, t}
  def handle_info({:DOWN, _ref, _type, pid, _info}, state) do
    GC.down(state.gc, pid)
    {:noreply, drop_monitor(state, pid)}
  end

  def handle_info(_, state), do: {:noreply, state}

  @spec pools_for_shard(non_neg_integer, atom) :: {atom, atom}
  defp pools_for_shard(shard, pubsub_server) do
    {_, _} = servers = :ets.lookup_element(pubsub_server, shard, 2)
    servers
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
end
