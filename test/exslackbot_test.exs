defmodule ExSlackBotTest do
  require Logger

  use ExUnit.Case
  doctest ExSlackBot

  defmodule SimpleSlackBot do
    use ExSlackBot.GitHubRepoBot
    
    def hello(msg, %{workdir: wrkdir} = state) do
      {stdout, 0} = System.cmd "ls", ["-la"], [cd: wrkdir]
      {:reply, "```#{stdout}```", state}
    end
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

  test "can start bots" do
    bots = Application.get_env(:exslackbot, :bots)
    Logger.debug "bots: #{inspect(bots, pretty: true)}"
    {:ok, pid} = ExSlackBot.Application.start :normal, bots
    Process.sleep 60000
    assert 1 + 1 == 2
  end
end
