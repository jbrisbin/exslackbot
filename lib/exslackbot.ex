defmodule ExSlackBot do
  @moduledoc ~s"""
  `ExSlackBot` provides a base upon which SlackBots can more easily be built. Each bot is addressable by a name and is supervised, so handles errors and restarts.
  """
  require Logger

  defmacro __using__(override_name \\ nil) do
    quote do
      require Logger
      use GenServer

      @override_name unquote(override_name)

      defp default_name do
        elems = String.split(to_string(__MODULE__) |> String.downcase, ".")
        String.replace(List.last(elems), ~r/slackbot|bot/, "") |> String.to_atom
      end

      def name do
        case @override_name do
          nil -> default_name
          n -> n
        end
      end

      def start_link do
        GenServer.start_link __MODULE__, [], name: name
      end

      def init([]) do
        {:ok, %{}}
      end

      def handle_cast(%{id: slack_id, channel: ch, file: file, args: [cmd | args]} = msg, state) do
        attrs = args_to_attributes(args)
        attrs = case file do
          nil -> attrs
          f -> Map.put(attrs, :file, f)
        end
        reply = try do
          call(cmd, msg, attrs, state)
        rescue
          err ->
            err_msg = Exception.format_stacktrace(System.stacktrace) 
            {:reply, %{
              color: "danger",
              pretext: "Failed to invoke Bot function `#{inspect(__MODULE__)}.#{cmd}(#{inspect(attrs)}, #{inspect(state)})`",
              text: "```#{err_msg}```"
            }, state}
        end
        handle_reply(ch, reply)
      end

      defp call(cmd, msg, attrs, state) do
        # Logger.debug "apply(#{inspect(__MODULE__)}, #{inspect(cmd)}, [#{inspect(attrs, pretty: true)}, #{inspect(state, pretty: true)}])"
        :erlang.apply(__MODULE__, String.to_atom(cmd), [attrs, state])
      end

      defp handle_reply(_, {:noreply, state}) do        
        {:noreply, state}
      end

      defp handle_reply(channel, {:reply, msg, state}) when is_binary(msg) do
        %{ok: true} = Slackex.request("chat.postMessage", [
          as_user: true,
          channel: channel,
          text: msg
        ])
        {:noreply, state}
      end

      defp handle_reply(channel, {:reply, msg, state}) when is_map(msg) do
        attachments = [
          %{
            fallback: Map.get(msg, :summary, ""),
            pretext: Map.get(msg, :pretext, ""), 
            text: Map.get(msg, :text, ""),
            title: Map.get(msg, :title, ""),
            color: Map.get(msg, :color, ""),
            mrkdwn_in: ["pretext", "text"]
          }
        ]
        {:ok, json} = JSX.encode(attachments)
        %{ok: true} = Slackex.request("chat.postMessage", [
          as_user: true,
          channel: channel,
          text: "",
          attachments: json
        ])
        {:noreply, state}
      end

      defp handle_reply(_, msg) do
        raise "Invalid reply message: #{inspect(msg)}. Should be `{:noreply, state}` or `{:reply, msg, state}`"
      end

      defp args_to_attributes(args) do
        Map.new args, fn a ->
          case String.split(a, "=") do
            [flag] -> {String.to_atom(flag), true}
            [k, "true"] -> {String.to_atom(k), true}
            [k, "false"] -> {String.to_atom(k), false}
            [k, v] -> {String.to_atom(k), v}
          end 
        end
      end

      defoverridable [
        name: 0,
        start_link: 0,
        init: 1,
        handle_cast: 2,
        handle_reply: 2,
        call: 4
      ]
    end
  end

end
