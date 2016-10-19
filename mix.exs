defmodule ExSlackBot.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exslackbot,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def description do
    ~S"""
    ExSlackBot is a helper library for writing SlackBots using the Slack Real-Time Messaging API.
    """
  end

  def package do
    [
      maintainers: ["Jon Brisbin"],
      licenses: ["Apache-2.0"],
      links: %{GitHub: "https://github.com/jbrisbin/exslackbot"}
    ]
  end

  def application do
    [applications: [:logger, :websocket_client, :slackex]]
  end

  defp deps do
    [
      {:websocket_client, "~> 1.1"},
      {:slackex, "~> 0.0.1"},
      {:temp, "~> 0.4"},
      {:ex_spec, "~> 1.0.0", only: :test},
      {:excoveralls, "~> 0.4.3", only: :test},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end
end
