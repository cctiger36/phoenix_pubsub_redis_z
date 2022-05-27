defmodule Phoenix.PubSub.RedisZ.RedisSubscriber do
  @moduledoc false

  require Logger

  use GenServer

  @type server_name :: atom
  @type t :: %{
          pubsub_name: atom,
          node_name: atom,
          redix_pid: pid | nil,
          reconnect_timer: :timer.tref() | nil,
          redis_opts: keyword
        }

  @reconnect_after_ms 5_000
  @redix_opts [:host, :port, :password, :database]

  @spec server_name(atom, non_neg_integer) :: server_name
  def server_name(pubsub_name, shard) do
    Module.concat(["#{pubsub_name}.RedisZ.Subscriber#{shard}"])
  end

  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts) do
    {server_name, opts} = Keyword.pop(opts, :server_name)
    Logger.info("Starts pubsub subscriber: #{server_name}")
    GenServer.start_link(__MODULE__, opts, name: server_name)
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %{
      pubsub_name: opts[:pubsub_name],
      node_name: opts[:node_name],
      redix_pid: nil,
      reconnect_timer: nil,
      redis_opts: opts[:redis_opts]
    }

    {:ok, establish_conn(state)}
  end

  @impl GenServer
  def handle_call({:subscribe, _pid, topic}, _from, state) do
    {:ok, _reference} = Redix.PubSub.subscribe(state.redix_pid, topic, self())
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, _pid, topic}, _from, state) do
    :ok = Redix.PubSub.unsubscribe(state.redix_pid, topic, self())
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:establish_conn, state) do
    {:noreply, establish_conn(%{state | reconnect_timer: nil})}
  end

  def handle_info(
        {:redix_pubsub, redix_pid, _reference, :subscribed, _},
        %{redix_pid: redix_pid} = state
      ) do
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, redix_pid, _reference, :unsubscribed, _},
        %{redix_pid: redix_pid} = state
      ) do
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, redix_pid, _reference, :disconnected, %{error: %{reason: reason}}},
        %{redix_pid: redix_pid} = state
      ) do
    Logger.error(
      "Phoenix.PubSub disconnected from Redis with reason #{inspect(reason)} (awaiting reconnection)"
    )

    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, redix_pid, _reference, :message, %{payload: bin_msg}},
        %{redix_pid: redix_pid, node_name: node_name, pubsub_name: pubsub_name} = state
      ) do
    case :erlang.binary_to_term(bin_msg) do
      {mode, target_node, topic, message, dispatcher}
      when mode == :only and target_node == node_name
      when mode == :except and target_node != node_name ->
        Phoenix.PubSub.local_broadcast(pubsub_name, topic, message, dispatcher)

      _ ->
        :ignore
    end

    {:noreply, state}
  end

  def handle_info({:EXIT, redix_pid, _reason}, %{redix_pid: redix_pid} = state) do
    {:noreply, establish_conn(state)}
  end

  def handle_info({:EXIT, _, _reason}, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, _state), do: :ok

  @spec schedule_reconnect(t) :: :timer.tref()
  defp schedule_reconnect(state) do
    if state.reconnect_timer, do: :timer.cancel(state.reconnect_timer)
    {:ok, timer} = :timer.send_after(@reconnect_after_ms, :establish_conn)
    timer
  end

  @spec establish_conn(t) :: t
  defp establish_conn(state) do
    redis_opts = Keyword.take(state.redis_opts, @redix_opts)
    opts = [{:sync_connect, true} | redis_opts]

    case Redix.PubSub.start_link(opts) do
      {:ok, redix_pid} -> %{state | redix_pid: redix_pid}
      {:error, _} -> establish_failed(state)
    end
  end

  @spec establish_failed(t) :: t
  defp establish_failed(state) do
    Logger.error("Unable to establish initial redis connection. Attempting to reconnect...")
    %{state | redix_pid: nil, reconnect_timer: schedule_reconnect(state)}
  end
end
