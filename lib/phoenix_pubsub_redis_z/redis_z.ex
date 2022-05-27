defmodule Phoenix.PubSub.RedisZ do
  @moduledoc false

  alias __MODULE__.{LocalSupervisor, RedisDispatcher, RedisSupervisor}

  use Supervisor

  @behaviour Phoenix.PubSub.Adapter
  @default_local_pool_size 2
  @default_publisher_pool_size 8

  @impl Phoenix.PubSub.Adapter
  defdelegate node_name(adapter_name), to: RedisDispatcher

  @impl Phoenix.PubSub.Adapter
  defdelegate broadcast(adapter_name, topic, message, dispatcher), to: RedisDispatcher

  @impl Phoenix.PubSub.Adapter
  defdelegate direct_broadcast(adapter_name, node_name, topic, message, dispatcher),
    to: RedisDispatcher

  @spec start_link(keyword) :: Supervisor.on_start()
  def start_link(opts) do
    adapter_name = Keyword.fetch!(opts, :adapter_name)
    supervisor_name = Module.concat(adapter_name, "Supervisor")
    Supervisor.start_link(__MODULE__, opts, name: supervisor_name)
  end

  @impl Supervisor
  def init(opts) do
    pubsub_name = Keyword.fetch!(opts, :name)
    adapter_name = Keyword.fetch!(opts, :adapter_name)
    compression_level = Keyword.get(opts, :compression_level, 0)
    local_pool_size = Keyword.get(opts, :local_pool_size, @default_local_pool_size)
    publisher_pool_size = Keyword.get(opts, :publisher_pool_size, @default_publisher_pool_size)

    node_name = opts[:node_name] || node()
    validate_node_name!(node_name)
    redises = parse_redis_urls(opts[:redis_urls])

    :ets.new(adapter_name, [:public, :named_table, read_concurrency: true])
    :ets.insert(adapter_name, {:node_name, node_name})
    :ets.insert(adapter_name, {:compression_level, compression_level})
    :ets.insert(adapter_name, {:local_pool_size, local_pool_size})
    :ets.insert(adapter_name, {:redises, redises})
    :ets.insert(adapter_name, {:redises_count, length(redises)})

    local_server_options = [
      pubsub_name: pubsub_name,
      adapter_name: adapter_name,
      node_name: node_name,
      pool_size: local_pool_size,
      redises_count: length(redises)
    ]

    redis_server_options = [
      pubsub_name: pubsub_name,
      adapter_name: adapter_name,
      node_name: node_name,
      redises: redises,
      publisher_pool_size: publisher_pool_size
    ]

    children = [
      {LocalSupervisor, local_server_options},
      {RedisSupervisor, redis_server_options}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @spec parse_redis_urls([binary]) :: [keyword]
  defp parse_redis_urls(urls) do
    for url <- urls do
      info = URI.parse(url)

      user_opts =
        case String.split(info.userinfo || "", ":") do
          [""] -> []
          [username] -> [username: username]
          [username, password] -> [username: username, password: password]
        end

      database = info.path |> String.split("/") |> Enum.at(1) |> String.to_integer()
      Keyword.merge(user_opts, host: info.host, port: info.port, database: database)
    end
  end

  @spec validate_node_name!(atom) :: :ok | no_return
  defp validate_node_name!(node_name) do
    if node_name in [nil, :nonode@nohost] do
      raise ArgumentError, ":node_name is a required option for unnamed nodes"
    end

    :ok
  end
end
