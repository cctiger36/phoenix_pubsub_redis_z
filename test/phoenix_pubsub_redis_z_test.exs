Application.put_env(
  :phoenix_pubsub,
  :test_adapter,
  {Phoenix.PubSub.RedisZ,
   node_name: :SAMPLE,
   redis_urls: [
     "redis://localhost:6379/0",
     "redis://localhost:6379/1",
     "redis://localhost:6379/2"
   ],
   node_name: "test@localhost"}
)

Code.require_file("#{Mix.Project.deps_paths()[:phoenix_pubsub]}/test/shared/pubsub_test.exs")
