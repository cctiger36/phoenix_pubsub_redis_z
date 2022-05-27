# credo:disable-for-this-file Credo.Check.Refactor.FunctionArity
defmodule Phoenix.PubSub.RedisZ.RedisDispatcher do
  @moduledoc false

  alias Phoenix.PubSub
  alias Phoenix.PubSub.RedisZ.{RedisPublisher, RedisSubscriber}

  @spec subscribe(atom, pid, binary) :: :ok
  def subscribe(pubsub_name, pid, topic) do
    subscriber = select_subscriber(pubsub_name, topic)
    GenServer.call(subscriber, {:subscribe, pid, topic})
  end

  @spec unsubscribe(atom, pid, binary) :: :ok
  def unsubscribe(pubsub_name, pid, topic) do
    subscriber = select_subscriber(pubsub_name, topic)
    GenServer.call(subscriber, {:unsubscribe, pid, topic})
  end

  @spec broadcast(atom, PubSub.topic(), PubSub.message(), PubSub.dispatcher()) ::
          :ok | {:error, term}
  def broadcast(adapter_name, topic, message, dispatcher) do
    pool_name = select_publisher_pool(adapter_name, topic)
    RedisPublisher.broadcast(pool_name, adapter_name, topic, message, dispatcher)
  end

  @spec direct_broadcast(
          atom,
          PubSub.node_name(),
          PubSub.topic(),
          PubSub.message(),
          PubSub.dispatcher()
        ) :: :ok | {:error, term}
  def direct_broadcast(adapter_name, node_name, topic, message, dispatcher) do
    pool_name = select_publisher_pool(adapter_name, topic)

    RedisPublisher.direct_broadcast(
      pool_name,
      adapter_name,
      node_name,
      topic,
      message,
      dispatcher
    )
  end

  @spec select_subscriber(atom, PubSub.topic()) :: atom
  defp select_subscriber(pubsub_name, topic) do
    {:ok, {_adapter, adapter_name}} = Registry.meta(pubsub_name, :pubsub)
    RedisSubscriber.server_name(pubsub_name, :erlang.phash2(topic, redises_count(adapter_name)))
  end

  @spec select_publisher_pool(atom, PubSub.topic()) :: atom
  defp select_publisher_pool(adapter_name, topic) do
    RedisPublisher.pool_name(adapter_name, :erlang.phash2(topic, redises_count(adapter_name)))
  end

  @spec node_name(atom) :: PubSub.node_name()
  def node_name(adapter_name) do
    :ets.lookup_element(adapter_name, :node_name, 2)
  end

  @spec redises_count(atom) :: pos_integer
  def redises_count(adapter_name) do
    :ets.lookup_element(adapter_name, :redises_count, 2)
  end
end
