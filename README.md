# ExSlackBot

`ExSlackBot` is an Elixir behavior, `Supervisor`, and router that makes it easier to write Slack Bots using Elixir (and Erlang, for that matter). It handles much of the plumbing for you by connecting to the [Slack Real-Time Messaging API](https://api.slack.com/rtm) and opens a WebSocket connection. It processes incoming `message` events and determines if the Bot user is being mentioned or if the message is from a direct message session. It takes the message text and breaks it up into space-separated tokens and attempts to route the message to a Slack Bot that is, under the hood, just an Elixir `GenServer` with some boilerplate coded added via the `ExSlackBot` behavior.

## Installation

Until it's released and [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `exslackbot` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:exslackbot, github: "jbrisbin/exslackbot"}]
    end
    ```

  2. Ensure `exslackbot` is started before your application:

    ```elixir
    def application do
      [applications: [:exslackbot]]
    end
    ```

Once installed in your application, add the `ExSlackBot.Supervisor` and `ExSlackBot.Router` to your supervision hierarchy. When starting the `Supervisor`, pass it a list of bot modules you want it to supervise. Here's a sample `Application` module that starts a supervisor for two different bots: `SimpleSlackBot` and `ComplexSlackBot`. Once launched, the bots will be accessible by sending a message to the bot user (either directly or via mention) that contains as its first element in the line, the name of the bot (by default the module name, downcased, and stripped of the words `slackbot` or `bot`).

```
defmodule SimpleSlackBot do
  use ExSlackBot

  def hello(args \\ %{}, state) do
    Logger.debug "hello #{inspect(args)}"
    {:reply, "hello world", state}
  end
end

defmodule ComplexSlackBot do
  use ExSlackBot, :complex

  def init([]) do
    {:ok, %{count: 1}}
  end

  def hello(args \\ [], state) do
    {:reply, "hello world #{state.count}", %{state | count: state.count + 1}}
  end
end

defmodule SlackBotApplication do
  use Application
  import Supervisor.Spec, warn: false

  def start(type \\ :normal, args \\ []) do
    children = [
      supervisor(ExSlackBot.Supervisor, [[SimpleSlackBot, ComplexSlackBot]]),
      worker(ExSlackBot.Router, [])
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

SlackBotApplication.start
```

After starting this application, your bot user should show up as active and sending it a message like:

```
simple hello
```

Should result in the library invoking the function `SimpleSlackBot.hello/2` and passing any arguments (`key=val` pairs that appear as the third element of the command line and beyond) as well as the module state.

## Implementing Functions

The bot library expects a command message to be space-spearated and take the following shape:

```
:bot_name: :command: :var[=true]: :var=value: ...
```

1. The first element must be the name of the bot. The name is derived from the module name or passed explicitly as an option on the `use` line.
2. The second element (`:command:`) will be turned into a function name passed to `:erlang.apply`.
3. Attributes can be set by their presence in the command (simply passing `attribute` sets an attribute in the argument map of `attribute: true`) or by specifying a value using `=`: `attribute=value`. The latter would result in having a key inside the argument map passed to your function of `%{attribute: "value"}`.

## TODO

* Reconnecting when `wss://` connection to Slack API is lost.
* Gist integration for large `STDOUT` and `STDERR` tracebacks.

## License

`ExSlackBot` is licensed under the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).
