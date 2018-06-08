defmodule PhoenixPubsubRedisZTest do
  alias Phoenix.PubSub
  alias Phoenix.PubSub.RedisZ
  alias Phoenix.PubSub.RedisZ.Local

  use ExUnit.Case, async: true

  def spawn_pid do
    spawn(fn -> :timer.sleep(:infinity) end)
  end

  setup_all do
    pubsub_server = TestApp.PubSub

    {:ok, _} =
      RedisZ.start_link(
        pubsub_server,
        redis_urls: [
          "redis://localhost:6379/0",
          "redis://localhost:6379/1",
          "redis://localhost:6379/2"
        ],
        node_name: "test@localhost"
      )

    {:ok, pubsub_server: pubsub_server}
  end

  test "#subscribe, #unsubscribe", %{pubsub_server: pubsub_server} do
    pid = spawn_pid()
    assert Local.subscribers(pubsub_server, "topic01", 0) == []
    assert PubSub.subscribe(pubsub_server, pid, "topic01") == :ok
    assert Local.subscribers(pubsub_server, "topic01", 0) == [pid]
    assert PubSub.unsubscribe(pubsub_server, pid, "topic01") == :ok
    assert Local.subscribers(pubsub_server, "topic01", 0) == []
  end

  test "broadcast/3 and broadcast!/3", %{pubsub_server: pubsub_server} do
    :ok = PubSub.subscribe(pubsub_server, self(), "topic02")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.broadcast(pubsub_server, "topic02", :ping)
    assert_receive :ping
    :ok = PubSub.broadcast!(pubsub_server, "topic02", :ping)
    assert_receive :ping
    :ok = PubSub.unsubscribe(pubsub_server, self(), "topic02")
    assert Local.subscribers(pubsub_server, "topic02", 0) == []
  end

  test "broadcast_from/4 and broadcast_from!/4", %{pubsub_server: pubsub_server} do
    pid = spawn_pid()
    :ok = PubSub.subscribe(pubsub_server, self(), "topic03")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.broadcast_from(pubsub_server, pid, "topic03", :ping)
    assert_receive :ping
    :ok = PubSub.broadcast_from!(pubsub_server, pid, "topic03", :ping)
    assert_receive :ping
  end

  test "broadcast_from/4 and broadcast_from!/4 skips sender", %{pubsub_server: pubsub_server} do
    :ok = PubSub.subscribe(pubsub_server, self(), "topic04")
    # wait until Redix subscribed
    Process.sleep(100)
    :ok = PubSub.broadcast_from(pubsub_server, self(), "topic04", :ping)
    refute_receive :ping
    :ok = PubSub.broadcast_from!(pubsub_server, self(), "topic04", :ping)
    refute_receive :ping
  end

  test "processes automatically removed from topic when killed", %{pubsub_server: pubsub_server} do
    pid = spawn_pid()
    :ok = PubSub.subscribe(pubsub_server, pid, "topic05")
    assert Local.subscribers(pubsub_server, "topic05", 0) == [pid]
    Process.exit(pid, :kill)
    # wait until GC removes dead pid
    Process.sleep(100)
    assert Local.subscribers(pubsub_server, "topic05", 0) == []
  end
end
