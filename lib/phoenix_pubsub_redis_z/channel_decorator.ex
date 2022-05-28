defmodule Phoenix.PubSub.RedisZ.ChannelDecorator do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @before_compile Phoenix.PubSub.RedisZ.ChannelDecorator
    end
  end

  defmacro __before_compile__(_env) do
    {kind, fun, arity} = {:def, :join, 3}
    [topic, _payload, socket] = args = generate_args(arity)

    body =
      quote do
        result = super(unquote_splicing(args))

        Phoenix.PubSub.RedisZ.Local.subscribe(
          unquote(socket).pubsub_server,
          self(),
          unquote(topic)
        )

        result
      end

    quote do
      defoverridable [{unquote(fun), unquote(arity)}]

      Kernel.unquote(kind)(unquote(fun)(unquote_splicing(args))) do
        unquote(body)
      end
    end
  end

  defp generate_args(n), do: for(i <- 1..n, do: Macro.var(:"var#{i}", __MODULE__))
end
