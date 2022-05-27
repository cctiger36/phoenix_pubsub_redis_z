defmodule Phoenix.PubSub.RedisZ.GC do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.RedisDispatcher

  require Logger

  use GenServer

  @type t :: %{
          topics: atom,
          pids: atom,
          pubsub_name: atom
        }

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts) do
    Logger.info("Starts pubsub_redis_z gc: #{opts[:server_name]}")
    GenServer.start_link(__MODULE__, opts, name: opts[:server_name])
  end

  @impl GenServer
  def init(opts) do
    {:ok,
     %{
       topics: opts[:local_name],
       pids: opts[:server_name],
       pubsub_name: opts[:pubsub_name]
     }}
  end

  def down(gc_server, pid) when is_atom(gc_server) do
    GenServer.cast(gc_server, {:down, pid})
  end

  @impl GenServer
  def handle_cast({:down, pid}, state) do
    try do
      topics = :ets.lookup_element(state.pids, pid, 2)

      for topic <- topics do
        true = :ets.match_delete(state.topics, {topic, pid})

        if :ets.match_object(state.topics, {topic, :_}, 1) == :"$end_of_table" do
          :ok = RedisDispatcher.unsubscribe(state.pubsub_name, pid, topic)
        end
      end

      true = :ets.match_delete(state.pids, {pid, :_})
    catch
      :error, :badarg -> :badarg
    end

    {:noreply, state}
  end
end
