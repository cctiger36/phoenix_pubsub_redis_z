defmodule Phoenix.PubSub.RedisZ.GC do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.RedisDispatcher

  require Logger

  use GenServer

  @type t :: %{
          topics: atom,
          pids: atom,
          pubsub_server: atom,
          redises_count: pos_integer
        }

  defdelegate down(gc_server, pid), to: Phoenix.PubSub.GC
  defdelegate handle_call(request, from, state), to: Phoenix.PubSub.GC

  @spec start_link(atom, atom, atom, pos_integer) :: GenServer.on_start()
  def start_link(server_name, local_name, pubsub_server, redises_count) do
    Logger.info("Starts pubsub gc: #{server_name}")

    GenServer.start_link(
      __MODULE__,
      {server_name, local_name, pubsub_server, redises_count},
      name: server_name
    )
  end

  @spec init({atom, atom, atom, pos_integer}) :: {:ok, t}
  def init({server_name, local_name, pubsub_server, redises_count}) do
    {:ok,
     %{
       topics: local_name,
       pids: server_name,
       pubsub_server: pubsub_server,
       redises_count: redises_count
     }}
  end

  @spec handle_cast(term, t) :: {:noreply, t}
  def handle_cast({:down, pid}, state) do
    try do
      topics = :ets.lookup_element(state.pids, pid, 2)

      for topic <- topics do
        true = :ets.match_delete(state.topics, {topic, {pid, :_}})

        if :ets.match_object(state.topics, {topic, :_}, 1) == :"$end_of_table" do
          RedisDispatcher.unsubscribe(state.pubsub_server, state.redises_count, pid, topic)
        end
      end

      true = :ets.match_delete(state.pids, {pid, :_})
    catch
      :error, :badarg -> :badarg
    end

    {:noreply, state}
  end
end
