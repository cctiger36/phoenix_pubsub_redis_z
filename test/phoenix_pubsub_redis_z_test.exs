defmodule PhoenixPubsubRedisZTest do
  alias Phoenix.PubSub
  alias Phoenix.PubSub.RedisZ.Local

  use ExUnit.Case, async: true

  def spawn_pid() do
    spawn(fn -> :timer.sleep(:infinity) end)
  end

  setup_all do
    pubsub = TestApp.PubSub
    node_name = "test@localhost"

    {:ok, _} =
      Phoenix.PubSub.Supervisor.start_link(
        name: pubsub,
        adapter: Phoenix.PubSub.RedisZ,
        redis_urls: [
          "redis://localhost:6379/0",
          "redis://localhost:6379/1",
          "redis://localhost:6379/2"
        ],
        compression_level: 1,
        node_name: node_name
      )

    {:ok, pubsub: pubsub, node_name: node_name}
  end

  test "#subscribe, #unsubscribe", %{pubsub: pubsub} do
    pid = spawn_pid()
    shard = :erlang.phash2(pid, 2)
    assert Local.subscribers(pubsub, "topic01", shard) == []
    assert Local.subscribe(pubsub, pid, "topic01") == :ok
    assert Local.subscribers(pubsub, "topic01", shard) == [pid]
    assert Local.unsubscribe(pubsub, pid, "topic01") == :ok
    assert Local.subscribers(pubsub, "topic01", shard) == []
  end

  test "direct_broadcast/3 and direct_broadcast!/3", %{pubsub: pubsub, node_name: node_name} do
    :ok = Local.subscribe(pubsub, self(), "topic02")
    :ok = PubSub.subscribe(pubsub, "topic02")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.direct_broadcast(node_name, pubsub, "topic02", :ping)
    assert_receive :ping
    :ok = PubSub.direct_broadcast!(node_name, pubsub, "topic02", :ping)
    assert_receive :ping
    :ok = PubSub.unsubscribe(pubsub, "topic02")
    :ok = Local.unsubscribe(pubsub, self(), "topic02")
    shard = :erlang.phash2(self(), 2)
    assert Local.subscribers(pubsub, "topic02", shard) == []
    :ok = PubSub.direct_broadcast!(node_name, pubsub, "topic02", :ping)
    refute_receive :ping
  end

  test "broadcast_from/4 and broadcast_from!/4", %{pubsub: pubsub} do
    pid = spawn_pid()
    :ok = Local.subscribe(pubsub, self(), "topic03")
    :ok = PubSub.subscribe(pubsub, "topic03")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.broadcast_from(pubsub, pid, "topic03", :ping)
    assert_receive :ping
    :ok = PubSub.broadcast_from!(pubsub, pid, "topic03", :ping)
    assert_receive :ping
  end

  test "broadcast_from/4 and broadcast_from!/4 [skip sender]", %{pubsub: pubsub} do
    :ok = Local.subscribe(pubsub, self(), "topic04")
    :ok = PubSub.subscribe(pubsub, "topic04")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.broadcast_from(pubsub, self(), "topic04", :ping)
    refute_receive :ping
    :ok = PubSub.broadcast_from!(pubsub, self(), "topic04", :ping)
    refute_receive :ping
  end

  test "processes automatically removed from topic when killed", %{pubsub: pubsub} do
    pid = spawn_pid()
    shard = :erlang.phash2(pid, 2)
    :ok = Local.subscribe(pubsub, pid, "topic05")
    assert Local.subscribers(pubsub, "topic05", shard) == [pid]
    Process.exit(pid, :kill)
    # wait until GC removes dead pid
    Process.sleep(100)
    assert Local.subscribers(pubsub, "topic05", shard) == []
  end
end
