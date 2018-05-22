defmodule Phoenix.PubSub.RedisZ.RedisPublisher do
  @moduledoc false

  require Logger

  def pool_name(pubsub_server, shard) do
    Module.concat(["#{pubsub_server}.RedisZ.PublisherPool#{shard}"])
  end

  def broadcast(fastlane, pool_name, pool_size, node_ref, from, topic, msg) do
    do_broadcast(fastlane, pool_name, pool_size, node_ref, from, topic, msg)
  end

  def direct_broadcast(fastlane, pool_name, pool_size, node_ref, _node_name, from, topic, msg) do
    do_broadcast(fastlane, pool_name, pool_size, node_ref, from, topic, msg)
  end

  defp do_broadcast(fastlane, pool_name, pool_size, node_ref, from, topic, msg) do
    redis_msg = {node_ref, fastlane, pool_size, from, topic, msg}
    bin_msg = :erlang.term_to_binary(redis_msg)

    :poolboy.transaction(pool_name, fn worker_pid ->
      case Redix.command(worker_pid, ["PUBLISH", topic, bin_msg]) do
        {:ok, _} ->
          :ok

        {:error, %Redix.ConnectionError{reason: :closed}} ->
          Logger.error("failed to publish broadcast due to closed redis connection")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end
end
