defmodule ExSlackBot.HelloWorldBot do
  use ExSlackBot, :hello

  def world(msg, state) do
    Logger.debug "#{inspect(msg, pretty: true)}"
    {:reply, "Hello World!", state}
  end
end