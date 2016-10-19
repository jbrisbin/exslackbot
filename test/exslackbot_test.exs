defmodule ExSlackBotTest do
  require Logger

  use ExUnit.Case
  doctest ExSlackBot

  defmodule SimpleSlackBot do
    use ExSlackBot
    import ExSlackBot.GitHubBot
  end

  defmodule ComplexSlackBot do
    use ExSlackBot, :complex

    def init([]) do
      {:ok, %{count: 1}}
    end

    def hello(args \\ %{}, state) do
      {:reply, "hello world #{state.count}", %{state | count: state.count + 1}}
    end
  end

  defmodule TestApplication do
    use Application
    import Supervisor.Spec, warn: false

    def start(type \\ nil, args \\ []) do
      children = [
        supervisor(ExSlackBot.Supervisor, [[SimpleSlackBot, ComplexSlackBot]]),
        worker(ExSlackBot.Router, [])
      ]
      Supervisor.start_link(children, strategy: :one_for_one)
    end
  end

  test "can start router" do
    {:ok, pid} = TestApplication.start
    Process.sleep 60000
    assert 1 + 1 == 2
  end
end
