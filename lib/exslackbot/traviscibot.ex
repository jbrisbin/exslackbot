defmodule ExSlackBot.TravisCIBot do
  @moduldoc ~s"""
  `TravisCIBot` is a generic bot to trigger builds on Travis CI using [the REST API](https://docs.travis-ci.com/user/triggering-builds).

  This bot responds to commands as messages or as comments on a file snippet. If sending the bot a message by mention or directly, the line should take the following shape:

  travis trigger repo=<org>/<repo> [branch=master]

  The above text can be put into the comment section of a file snippet share, where the content of the file is a JSON document that will be sent to the Travis CI REST API. An example bit of JSON to set an environment variable might be:

  ```
  {
    "request": {
      "branch": "master",
      "config": {
        "env": {
          "global": ["OVERRIDE=true"]
        }
      }
    }
  }
  ```
  """
  use ExSlackBot, :travis

  def init([]) do
    token = System.get_env("TRAVIS_TOKEN") || ""
    {:ok, %{token: token}}
  end

  @doc ~s"""
  The `trigger` function will invoke the Travis CI REST API for the given repository (passed by setting the attribute `repo=`).
  """
  def trigger(%{repo: repo} = args, %{token: token} = state) do
    repo_name = String.replace repo, "/", "%2F"
    url = "https://api.travis-ci.org/repo/#{repo_name}/requests"

    # Get the branch name from the attributes sent with the command or default to `master`
    branch = case args do
      %{branch: branch} -> branch
      _ -> "master"
    end
    # Get the basic JSON to send to Travis. If not specified via snippet, pass the branch name.
    json = case args do
      %{file: content} -> content
      _ -> "{\"request\":{\"branch\":\"#{branch}\"}}"
    end
    Logger.info "Travis CI: Triggering build on repo #{repo}@#{branch}"
    Logger.debug "Travis CI: Sending JSON #{json}"
    # Invoke the REST API with a POST
    {color, text} = case HTTPoison.post! url, json, [
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Travis-API-Version": "3",
      "Authorization": "token #{token}"
    ] do
      %HTTPoison.Response{body: body, status_code: status} when status < 300 ->
        # Post to Slack indicating success
        {"good", "```#{body}```"}
      resp -> 
        # Post to Slack indicating failure
        {"danger", "```#{inspect(resp, pretty: true)}```"}
    end
    {:reply, %{summary: "Triggered #{repo}", color: color, text: text}, state}
  end

end
