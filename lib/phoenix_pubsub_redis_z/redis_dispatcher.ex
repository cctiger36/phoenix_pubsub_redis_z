# credo:disable-for-this-file Credo.Check.Refactor.FunctionArity
defmodule Phoenix.PubSub.RedisZ.RedisDispatcher do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{RedisPublisher, RedisSubscriber}

  @spec subscribe(atom, pos_integer, pid, binary) :: :ok
  def subscribe(pubsub_server, redises_count, pid, topic) do
    subscriber = select_subscriber(pubsub_server, redises_count, topic)
    GenServer.call(subscriber, {:subscribe, pid, topic})
  end

  @spec unsubscribe(atom, pos_integer, pid, binary) :: :ok
  def unsubscribe(pubsub_server, redises_count, pid, topic) do
    subscriber = select_subscriber(pubsub_server, redises_count, topic)
    GenServer.call(subscriber, {:unsubscribe, pid, topic})
  end

  @spec broadcast(term, atom, pos_integer, pos_integer, reference, pid, binary, map) ::
          :ok | {:error, term}
  def broadcast(fastlane, pubsub_server, pool_size, redises_count, node_ref, from, topic, msg) do
    publisher = select_publisher(pubsub_server, redises_count, topic)
    RedisPublisher.broadcast(fastlane, publisher, pool_size, node_ref, from, topic, msg)
  end

  @spec direct_broadcast(term, atom, pos_integer, pos_integer, reference, atom, pid, binary, map) ::
          :ok | {:error, term}
  def direct_broadcast(
        fastlane,
        pubsub_server,
        pool_size,
        redises_count,
        node_ref,
        node_name,
        from,
        topic,
        msg
      ) do
    publisher = select_publisher(pubsub_server, redises_count, topic)

    RedisPublisher.direct_broadcast(
      fastlane,
      publisher,
      pool_size,
      node_ref,
      node_name,
      from,
      topic,
      msg
    )
  end

  @spec select_subscriber(atom, pos_integer, binary) :: atom
  defp select_subscriber(pubsub_server, redises_count, topic) do
    RedisSubscriber.server_name(pubsub_server, :erlang.phash2(topic, redises_count))
  end

  @spec select_publisher(atom, pos_integer, binary) :: atom
  defp select_publisher(pubsub_server, redises_count, topic) do
    RedisPublisher.pool_name(pubsub_server, :erlang.phash2(topic, redises_count))
  end
end
