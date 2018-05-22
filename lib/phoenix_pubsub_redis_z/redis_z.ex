defmodule Phoenix.PubSub.RedisZ do
  @moduledoc false

  alias Phoenix.PubSub.RedisZ.{LocalSupervisor, RedisSupervisor}

  use Supervisor

  @default_publisher_pool_size 8

  def start_link(name, options) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, options], name: supervisor_name)
  end

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
  def node_name(nil), do: node()
  def node_name(configured_name), do: configured_name

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

  defp validate_node_name!(options) do
    case options[:node_name] || node() do
      name when name in [nil, :nonode@nohost] ->
        raise ArgumentError, ":node_name is a required option for unnamed nodes"

      name ->
        name
    end
  end
end
