defmodule Phoenix.PubSub.RedisZ.RedisPublisher do
  @moduledoc false

  alias Phoenix.PubSub
  alias Phoenix.PubSub.RedisZ.RedisDispatcher

  require Logger

  @type pool_name :: atom
  @type mode :: :except | :only

  @spec pool_name(atom, non_neg_integer) :: pool_name
  def pool_name(adapter_name, shard) do
    Module.concat(["#{adapter_name}.RedisZ.PublisherPool#{shard}"])
  end

  @spec broadcast(pool_name, atom, PubSub.topic(), PubSub.message(), PubSub.dispatcher()) ::
          :ok | {:error, term}
  def broadcast(pool_name, adapter_name, topic, message, dispatcher) do
    publish(
      pool_name,
      adapter_name,
      :except,
      RedisDispatcher.node_name(adapter_name),
      topic,
      message,
      dispatcher
    )
  end

  @spec direct_broadcast(
          pool_name,
          atom,
          PubSub.node_name(),
          PubSub.topic(),
          PubSub.message(),
          PubSub.dispatcher()
        ) :: :ok | {:error, term}
  def direct_broadcast(pool_name, adapter_name, node_name, topic, message, dispatcher) do
    publish(pool_name, adapter_name, :only, node_name, topic, message, dispatcher)
  end

  @spec publish(
          pool_name,
          atom,
          mode,
          PubSub.node_name(),
          PubSub.topic(),
          PubSub.message(),
          PubSub.dispatcher()
        ) :: :ok | {:error, term}
  defp publish(pool_name, adapter_name, mode, node_name, topic, message, dispatcher) do
    redis_msg = {mode, node_name, topic, message, dispatcher}
    compression_level = compression_level(adapter_name)
    bin_msg = :erlang.term_to_binary(redis_msg, compressed: compression_level)

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

  @spec compression_level(atom) :: 0..9
  defp compression_level(adapter_name) do
    :ets.lookup_element(adapter_name, :compression_level, 2)
  end
end
