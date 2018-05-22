defmodule Phoenix.PubSub.RedisZ.RedisDispatcher do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{RedisPublisher, RedisSubscriber}

  def subscribe(pubsub_server, redises_count, pid, topic) do
    subscriber = select_subscriber(pubsub_server, redises_count, topic)
    GenServer.call(subscriber, {:subscribe, pid, topic})
  end

  def unsubscribe(pubsub_server, redises_count, pid, topic) do
    subscriber = select_subscriber(pubsub_server, redises_count, topic)
    GenServer.call(subscriber, {:unsubscribe, pid, topic})
  end

  def broadcast(fastlane, pubsub_server, pool_size, redises_count, node_ref, from, topic, msg) do
    publisher = select_publisher(pubsub_server, redises_count, topic)
    RedisPublisher.broadcast(fastlane, publisher, pool_size, node_ref, from, topic, msg)
  end

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

  defp select_subscriber(pubsub_server, redises_count, topic) do
    RedisSubscriber.server_name(pubsub_server, :erlang.phash2(topic, redises_count))
  end

  defp select_publisher(pubsub_server, redises_count, topic) do
    RedisPublisher.pool_name(pubsub_server, :erlang.phash2(topic, redises_count))
  end
end
