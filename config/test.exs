use Mix.Config

config :exslackbot,
  bots: [
    ExSlackBot.TravisCIBot, 
    ExSlackBot.CommandBot, 
    ExSlackBotTest.ComplexSlackBot, 
    ExSlackBotTest.SimpleSlackBot
  ],
  simple: [repo: "jbrisbin/exslackbot", branch: "master"]