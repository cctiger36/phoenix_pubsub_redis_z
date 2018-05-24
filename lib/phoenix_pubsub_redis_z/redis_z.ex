defmodule Phoenix.PubSub.RedisZ do
  @moduledoc """
  Yet another Redis PubSub adapter for Phoenix. Supports sharding across multiple redis nodes.

  Add `:phoenix_pubsub_redis_z` to your deps:

      defp deps do
        [
          {:phoenix_pubsub_redis_z, "~> 0.1.0"}
        ]
      end

  Then add it to your Endpoint's config:

      config :my_app, MyApp.Endpoint,
        pubsub: [
          name: MyApp.PubSub,
          adapter: Phoenix.PubSub.RedisZ,
          redis_urls: ["redis://redis01:6379/0", "redis://redis02:6379/0"]
        ]

  ## Options

    * `:name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`
    * `:redis_urls` - The required redis-server URL list
    * `:node_name` - The name of the node. Defaults `node()`
    * `:pool_size` - The pool size of local pubsub server. Defaults 1
    * `:publisher_pool_size` - The pool size of redis publish connections for each redis-server. Defaults 8
    * `:publisher_max_overflow`: Maximum number of publish connections created if pool is empty.

  """

  alias Phoenix.PubSub.RedisZ.{LocalSupervisor, RedisSupervisor}

  use Supervisor

  @default_publisher_pool_size 8

  @spec start_link(atom, keyword) :: Supervisor.on_start()
  def start_link(name, options) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, options], name: supervisor_name)
  end

  @spec init(list) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}} | :ignore
  def init([server_name, options]) do
    node_ref = :crypto.strong_rand_bytes(24)
    redises = parse_redis_urls(options[:redis_urls])

    local_server_options = [
      server_name: server_name,
      node_ref: node_ref,
      pool_size: options[:pool_size] || 1,
      redises_count: length(redises),
      node_name: validate_node_name!(options),
      fastlane: options[:fastlane]
    ]

    redis_server_options = [
      pubsub_server: server_name,
      node_ref: node_ref,
      redises: redises,
      publisher_pool_size: options[:publisher_pool_size] || @default_publisher_pool_size,
      publisher_max_overflow: options[:publisher_max_overflow] || 0
    ]

    children = [
      supervisor(LocalSupervisor, [local_server_options]),
      supervisor(RedisSupervisor, [redis_server_options])
    ]

    supervise(children, strategy: :rest_for_one)
  end

  @doc false
  @spec node_name(node | nil) :: node
  def node_name(nil), do: node()
  def node_name(configured_name), do: configured_name

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

  @spec validate_node_name!(keyword) :: node | no_return
  defp validate_node_name!(options) do
    case options[:node_name] || node() do
      name when name in [nil, :nonode@nohost] ->
        raise ArgumentError, ":node_name is a required option for unnamed nodes"

      name ->
        name
    end
  end
end
