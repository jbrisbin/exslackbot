defmodule ExSlackBot.Supervisor do
  @moduledoc ~s"""
  `ExSlackBot.Supervisor` is a process supervisor that makes it easy to supervise bot modules that mix in the `ExSlackBot` behavior. It provides a bit of simplicity in dealing with bots that register their `GenServers` under simple names.
  """
  require Logger

  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args)
  end

  @doc """
  Take a list of module atoms and turn that into a list of worker configurations to pass to the supervisor.
  """
  def init(bots \\ []) do
    children = for bot <- bots do
      worker(bot, [], id: bot.name)
    end
    Logger.debug "Supervising Slack Bots: #{inspect(children)}"
    supervise(children, strategy: :one_for_one)
  end

end