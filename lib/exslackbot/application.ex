defmodule ExSlackBot.Application do
  require Logger
  use Application

  import Supervisor.Spec, warn: false

  def start(_type \\ :normal, bots \\ []) do
    children = [
      supervisor(ExSlackBot.Supervisor, [bots]),
      worker(ExSlackBot.Router, [])
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end