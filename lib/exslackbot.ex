defmodule ExSlackBot do
  @moduledoc ~s"""
  `ExSlackBot` provides a base upon which SlackBots can more easily be built. Each bot is addressable by a name and is supervised, so handles errors and restarts.
  """

  defmacro __using__(name_or_opts \\ :name) do
    opts = cond do
      is_atom(name_or_opts) -> [name: name_or_opts]
      is_list(name_or_opts) -> name_or_opts
      true -> raise "argument must be atom (command name) or keyword list (opts)"
    end
    quote do
      require Logger

      use GenServer

      defp default_name do
        elems = String.split(to_string(__MODULE__) |> String.downcase, ".")
        String.replace(List.last(elems), ~r/slackbot|bot/, "") |> String.to_atom
      end

      def name do
        unquote(opts[:name]) || default_name
      end

      def start_link do
        GenServer.start_link __MODULE__, [], name: name()
      end

      def init([]) do
        {:ok, %{}}
      end

      def handle_cast({slack_id, _, channel, socket, file, [cmd | args]}, state) do
        fn_args = Map.new args, fn a ->
          case String.split(a, "=") do
            [flag] -> {String.to_atom(flag), true}
            [k, "true"] -> {String.to_atom(k), true}
            [k, "false"] -> {String.to_atom(k), false}
            [k, v] -> {String.to_atom(k), v}
          end 
        end
        fn_args = case file do
          nil -> fn_args
          f -> Map.put(fn_args, :file, f)
        end
        reply = try do
          Logger.debug "apply(#{inspect(__MODULE__)}, #{inspect(cmd)}, [#{inspect(fn_args)}, #{inspect(state)}])"
          :erlang.apply(__MODULE__, String.to_atom(List.first(cmd)), [fn_args, state])
        rescue
          err -> {:reply, %{
            color: "danger",
            pretext: "Failed to invoke Bot function `#{inspect(__MODULE__)}.#{cmd}(#{inspect(fn_args)}, #{inspect(state)})`",
            text: "```#{inspect(err)}```"
          }, state}
        end
        handle_reply(channel, reply)
      end

      defp handle_reply(_, {:noreply, state}) do        
        {:noreply, state}
      end

      defp handle_reply(channel, {:reply, msg, state}) when is_map(msg) do
        attachments = [
          %{
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

      defp handle_reply(channel, {:reply, msg, state}) when is_binary(msg) do
        %{ok: true} = Slackex.request("chat.postMessage", [
          as_user: true,
          channel: channel,
          text: msg
        ])
        {:noreply, state}
      end

      defp handle_reply(_, msg) do
        raise "Invalid reply message: #{inspect(msg)}. Should be `{:noreply, state}` or `{:reply, msg, state}`"
      end

      defoverridable Module.definitions_in __MODULE__
    end
  end

end
