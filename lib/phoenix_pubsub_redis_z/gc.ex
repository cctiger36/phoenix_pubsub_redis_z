defmodule Phoenix.PubSub.RedisZ.GC do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.RedisDispatcher

  require Logger

  use GenServer

  defdelegate down(gc_server, pid), to: Phoenix.PubSub.GC
  defdelegate handle_call(request, from, state), to: Phoenix.PubSub.GC

  def start_link(server_name, local_name, pubsub_server, redises_count) do
    Logger.info("Starts pubsub gc: #{server_name}")

    GenServer.start_link(
      __MODULE__,
      {server_name, local_name, pubsub_server, redises_count},
      name: server_name
    )
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
end
