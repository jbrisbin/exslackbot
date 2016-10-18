defmodule ExSlackBot.Router do
  @moduledoc ~s"""
  `ExSlackBot.Router` is responsible for routing messages received from the Slack Real-Time Messaging API and routing them to a `GenServer` registered under a name that corresponds to the first segement of the command text--which is the text of the message, split on whitespace. 

  The router will do a `GenServer.cast` to a server named whatever is first in the command text. The next space-separated segement of the command text is considered the callback name. A function should exist in the bot module with this name. Subsequent segments of the command text are considered "attributes". If they exist in the command text, their value is `true`. Otherwise, their value is what appears immediately after the `=` (no spaces around the `=`). e.g. `hello world attribute=value` will result in the router dispatching a call to the function `HelloSlackBot.world/2` and passing arguments `%{attribute: "value"}, state`. Where `state` is the initial state of the bot, returned by `init/1`, which is overridable.
  """
  require Logger

  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    case Slackex.RTM.start do
      %{ok: true, url: url} = resp ->
        # Parse the WebSocket URL out of the response 
        case URI.parse(url) do
          %URI{host: host, path: path} ->
            # Connect to Slack RTM API over secure WebSocket
            socket = Socket.Web.connect! host, path: path, secure: true

            # Start a Task to read from the socket
            {:ok, pid} = Task.start_link __MODULE__, :read, [socket, resp.self.id]
            Process.monitor pid

            # Starting args
            {:ok, %{
              slack_id: resp.self.id, 
              #channels: resp.channels, 
              socket: socket
            }}
          resp -> {:stop, resp}
        end
      resp -> {:stop, resp}
    end  
  end

  # Read data from the WebSocket connection and route according to the follow rules:
  #
  # 1: If it's text, parse the JSON and pass it on. 
  # 2: If a `ping`, respond with a `pong`. 
  # 3: Else, raise an error.
  def read(socket, slack_id) do
    case socket |> Socket.Web.recv! do
      {:text, data} -> 
        # Decode JSON with atoms and labels, pass it to ourselves via `gen_server:cast`
        {:ok, json} = JSX.decode(data, [{:labels, :atom}])
        # Logger.debug "message: #{inspect(json)}"
        decode(json, socket, slack_id)
      {:ping, _ } -> 
        # Respond with a `pong` to keep the connection alive
        socket |> Socket.Web.send!({:pong, ""})
      err ->
        raise "Error reading from #{inspect(socket)} #{inspect(err)}"
    end  
    read(socket, slack_id)
  end

  defp decode(%{type: "hello"}, _, slack_id) do
    Logger.info "Connected to RTM API as bot user #{slack_id}"
  end
  defp decode(%{type: "reconnect_url"}, _, _) do
    # Ignore
  end
  defp decode(%{type: "presence_change"}, _, _) do
    # Ignore
  end
  defp decode(%{type: "user_typing"}, _, _) do
    # Ignore
  end
  defp decode(%{type: "file_shared"}, _, _) do
    # Ignore
  end

  # Consider an edited message another, separate command.
  defp decode(%{type: type, subtype: "message_changed", message: msg, channel: channel}, socket, slack_id) do
    decode(%{type: type, text: msg.text, channel: channel}, socket, slack_id)
  end

  defp decode(%{type: type, upload: true, file: %{permalink_public: permalink, initial_comment: %{comment: text0}}, channel: channel} = msg, socket, slack_id) do
    body = case HTTPoison.get! permalink do
      %HTTPoison.Response{body: body, status_code: status} when status < 300 -> 
        body
      resp ->
        Logger.error "#{inspect(resp, pretty: true)}" 
        nil
    end
    send_cmd(text0, slack_id, type, channel, socket, body)
  end

  # Decode the message and send to the correct `GenServer` based on the first element of the text.
  defp decode(%{type: type, text: text0, channel: channel}, socket, slack_id) do
    send_cmd(text0, slack_id, type, channel, socket)
  end

  defp send_cmd(text0, slack_id, type, channel, socket, file \\ nil) do
    case split_cmd_text(text0, channel, slack_id) do
      nil -> :noop
      {cmd, args} ->
        # Logger.debug "GenServer.cast(#{inspect(cmd)} #{inspect({slack_id, type, channel, socket, file, args})})" 
        GenServer.cast(cmd, {slack_id, type, channel, socket, file, args})
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