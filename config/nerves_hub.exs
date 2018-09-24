use Mix.Config

config :nerves_hub_cli, NervesHubCLI.API,
  host: "0.0.0.0",
  port: 4002

config :nerves_hub_cli,
  home: Path.expand("../.nerves-hub"),
  ca_certs: Path.expand("../test/fixtures/ca_certs")

config :nerves_hub, NervesHub.Socket,
  url: "wss://nerves-hub.org:4001/socket/websocket"

config :nerves_hub,
  ca_certs: "/etc/ssl_dev"
