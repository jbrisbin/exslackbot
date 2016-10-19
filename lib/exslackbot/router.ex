defmodule ExSlackBot.Router do
  @moduledoc ~s"""
  `ExSlackBot.Router` is responsible for routing messages received from the Slack Real-Time Messaging API and routing them to a `GenServer` registered under a name that corresponds to the first segement of the command text--which is the text of the message, split on whitespace. 

  The router will do a `GenServer.cast` to a server named whatever is first in the command text. The next space-separated segement of the command text is considered the callback name. A function should exist in the bot module with this name. Subsequent segments of the command text are considered "attributes". If they exist in the command text, their value is `true`. Otherwise, their value is what appears immediately after the `=` (no spaces around the `=`). e.g. `hello world attribute=value` will result in the router dispatching a call to the function `HelloSlackBot.world/2` and passing arguments `%{attribute: "value"}, state`. Where `state` is the initial state of the bot, returned by `init/1`, which is overridable.
  """
  require Logger

  @behaviour :websocket_client

  def start_link do
    case Slackex.RTM.start do
      %{ok: true, url: url} = resp ->
        # Connect to Slack RTM API over secure WebSocket
        :websocket_client.start_link(String.to_charlist(url), __MODULE__, [url, resp.self.id])
      resp -> 
        {:stop, resp}
    end  
  end

  def init([url, slack_id]) do
    {:once, %{url: url, slack_id: slack_id}}
  end

  def onconnect(_req, state) do
    {:ok, state}
  end

  def ondisconnect(reason, state) do
    Logger.debug "disconnected: #{inspect(reason, pretty: true)}"
    {:close, state}
  end

  def websocket_handle({:ping, ""}, _, state) do
    {:ok, state}
  end

  def websocket_handle({:text, msg}, _, state) do
    {:ok, json} = JSX.decode msg, [{:labels, :atom}]
    Logger.debug "msg: #{inspect(json, pretty: true)}"
    decode(json, state.slack_id)
    {:ok, state}
  end

  def websocket_info(msg, _, state) do
    Logger.debug "msg: #{inspect(msg, pretty: true)}"
    {:ok, state}
  end

  def websocket_terminate(reason, _, _) do
    Logger.debug "terminated: #{inspect(reason, pretty: true)}"
    :ok
  end

  defp decode(%{type: "hello"}, slack_id) do
    Logger.info "Connected to RTM API as bot user #{slack_id}"
  end
  defp decode(%{type: "reconnect_url"}, _) do
    # Ignore
  end
  defp decode(%{type: "presence_change"}, _) do
    # Ignore
  end
  defp decode(%{type: "user_typing"}, _) do
    # Ignore
  end
  defp decode(%{type: "file_shared"}, _) do
    # Ignore
  end
  defp decode(%{type: "file_change"}, _) do
    # Ignore
  end
  defp decode(%{type: "file_public"}, _) do
    # Ignore
  end
  defp decode(%{user: user}, slack_id) when user == slack_id do
    # Ignore messages sent from ourselves
  end

  # Consider an edited message another, separate command.
  defp decode(%{type: type, subtype: "message_changed", message: msg, channel: channel}, slack_id) do
    decode(%{type: type, text: msg.text, channel: channel}, slack_id)
  end

  defp decode(%{type: type, upload: true, file: %{url_private: permalink, initial_comment: %{comment: text0}}, channel: channel}, slack_id) do
    # Logger.debug "#{inspect(msg, pretty: true)}"
    token = System.get_env "SLACK_TOKEN"
    body = case HTTPoison.get! permalink, ["Authorization": "Bearer #{token}"], [follow_redirect: true] do
      %HTTPoison.Response{body: body, status_code: status} when status < 300 -> 
        body
      resp ->
        Logger.error "#{inspect(resp, pretty: true)}" 
        nil
    end
    send_cmd(text0, slack_id, type, channel, body)
  end

  # Decode the message and send to the correct `GenServer` based on the first element of the text.
  defp decode(%{type: type, text: text0, channel: channel}, slack_id) do
    send_cmd(text0, slack_id, type, channel)
  end

  defp send_cmd(text0, slack_id, type, channel, file \\ nil) do
    case split_cmd_text(text0, channel, slack_id) do
      nil -> :noop
      {cmd, args} ->
        # Logger.debug "GenServer.cast(#{inspect(cmd)} #{inspect({slack_id, type, channel, file, args})})" 
        GenServer.cast(cmd, {slack_id, type, channel, file, args})
    end
  end

  defp split_cmd_text(text0, channel, slack_id) do
    text = case String.contains? text0, slack_id do
      # Handle a mention
      true -> String.replace(text0, ~r/<(.*)>/, "")
      # Handle a private message
      _ -> case channel do
        "D" <> _ -> text0
        _ -> ""
      end
    end
    case String.split(text) do
      [] -> nil
      [cmd | args] -> {String.to_atom(cmd), args}
    end
  end

end