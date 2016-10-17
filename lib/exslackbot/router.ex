defmodule ExSlackBot.Router do
  @moduledoc ~s"""

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
          %URI{host: host, path: path} = uri ->
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
        decode(json, socket, slack_id)
      {:ping, _ } -> 
        # Respond with a `pong` to keep the connection alive
        socket |> Socket.Web.send!({:pong, ""})
      err ->
        raise "Error reading from #{inspect(socket)} #{inspect(err)}"
    end  
    read(socket, slack_id)
  end

  defp decode(%{type: "hello"}, _, _) do
    # Ignore
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

  # Consider an edited message another, separate command.
  defp decode(%{type: type, subtype: "message_changed", message: msg, channel: channel}, socket, slack_id) do
    decode(%{type: type, text: msg.text, channel: channel}, socket, slack_id)
  end

  # Decode the message and send to the correct `GenServer` based on the first element of the text.
  defp decode(%{type: type, text: text0, channel: channel}, socket, slack_id) do
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
      [cmd | args] -> 
        Logger.debug "#{cmd} [#{type}, #{channel}] ++ [#{inspect(args)}]"
        GenServer.cast(String.to_atom(cmd), [slack_id, type, channel, socket, args])
      [] -> :noop
    end
  end

end