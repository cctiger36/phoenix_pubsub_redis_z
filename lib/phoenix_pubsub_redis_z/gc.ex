defmodule Phoenix.PubSub.RedisZ.GC do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.RedisDispatcher

  require Logger

  use GenServer

  def start_link(server_name, local_name, pubsub_server, redises_count) do
    Logger.info("Starts pubsub gc: #{server_name}")

    GenServer.start_link(
      __MODULE__,
      {server_name, local_name, pubsub_server, redises_count},
      name: server_name
    )
  end

  def down(gc_server, pid) when is_atom(gc_server) do
    GenServer.cast(gc_server, {:down, pid})
  end

  def init({server_name, local_name, pubsub_server, redises_count}) do
    {:ok,
     %{
       topics: local_name,
       pids: server_name,
       pubsub_server: pubsub_server,
       redises_count: redises_count
     }}
  end

  def handle_call({:subscription, pid}, _from, state) do
    {:reply, subscription(state.pids, pid), state}
  end

  def handle_cast({:down, pid}, state) do
    try do
      topics = :ets.lookup_element(state.pids, pid, 2)

      for topic <- topics do
        RedisDispatcher.unsubscribe(state.pubsub_server, state.redises_count, pid, topic)
        true = :ets.match_delete(state.topics, {topic, {pid, :_}})
      end

      true = :ets.match_delete(state.pids, {pid, :_})
    catch
      :error, :badarg -> :badarg
    end

    {:noreply, state}
  end

  defp subscription(pids_table, pid) do
    try do
      :ets.lookup_element(pids_table, pid, 2)
    catch
      :error, :badarg -> []
    end
  end
end
