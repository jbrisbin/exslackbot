defmodule ExSlackBot.CommandBot do
  require Logger
  use ExSlackBot.GitHubRepoBot, name: :sh

  defp call(_, %{args: [sh | args]} = _msg, _, %{workdir: workdir} = state) do
    {out, status} = System.cmd sh, args, [cd: workdir, stderr_to_stdout: true] 
    color = cond do
      status == 0 -> "good"
      true -> "danger"
    end
    txt = "```\n#{out}\n```"
    {:reply, %{color: color, text: txt}, state}
  end

end