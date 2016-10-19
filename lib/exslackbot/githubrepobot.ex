defmodule ExSlackBot.GitHubRepoBot do
  @moduledoc ~s"""
  `GitHubRepoBot` is an Elixir behavior that makes working with GitHub repositories easier. You can assign a repo to the bot by passing `repo: "org/repo"` and optionally `branch: "branch_or_tag"` to the options when declaring the behavior in the `use` statement.
  """

  defmacro __using__(opts \\ nil) do
    quote do
      require Logger
      use ExSlackBot, unquote(opts[:name])

      def init([]) do
        Temp.track!
        workdir = Temp.mkdir!
        state = %{workdir: workdir}
        cloned = cond do
          unquote(opts[:repo]) != nil ->
            repo = unquote(opts[:repo])
            {:ok, _, _} = git(["clone", "https://github.com/#{repo}.git", workdir], state)
            if unquote(opts[:branch_or_tag]) != nil do
              {:ok, _, _} = git(["checkout", unquote(opts[:branch_or_tag])], state)
            end
            true
          true -> 
            false
        end        
        {:ok, %{workdir: workdir, cloned: cloned}}
      end

      def handle_cast(%{channel: ch} = msg, %{cloned: true} = state) do
        {:ok, _, _} = git(["pull"], state)
        super(msg, state)
      end

      def handle_cast(%{channel: ch, args: [repo | args]} = msg, %{workdir: workdir0, cloned: false} = state0) do
        # Figure out a branch name from what's after the '@'
        {repo_name, branch} = case String.split(repo, "@") do
          [r, b] -> {r, b}
          [r] -> {r, nil}
        end 
        # Create a 1-time use temp dir for this clone
        tmpdir = Temp.mkdir!
        state = %{state0 | workdir: tmpdir}
        # Clone the repo
        {:ok, _, _} = git(["clone", "https://github.com/#{repo_name}.git", tmpdir], state)
        if branch != nil do
          # Checkout a specific branch
          {:ok, _, _} = git(["checkout", branch], state)
        end
        # Invoke the standard routing logic to get the right callback
        reply = super(%{msg | args: args}, state)
        # Remove the temporary workdir, which includes this clone
        File.rm_rf tmpdir
        # Reply with a state updated to use the original, bot-wide temp dir
        case reply do
          {:noreply, _} -> {:noreply, %{state0 | workdir: workdir0}}
          {:reply, msg, _} -> {:reply, msg, %{state0 | workdir: workdir0}}
        end
      end

      # Perform git operations by using the CLI
      defp git(args, %{workdir: workdir} = state) do
        case System.cmd("git", args, [cd: workdir, stderr_to_stdout: true]) do
          {output, 0} -> 
            Logger.debug "#{output}"
            {:ok, output, state}
          {err, _} -> 
            raise err
        end
      end

      defoverridable [
        init: 1,
        handle_cast: 2,
        git: 2
      ]
    end
  end

end