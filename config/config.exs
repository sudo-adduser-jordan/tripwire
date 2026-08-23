import Config

config :ueberauth, Ueberauth,
  providers: [
    evesso:
      {Ueberauth.Strategy.EVESSO,
       [
         uid_field: :character_id,
         default_scope:
           ~w(esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-ui.open_window.v1 esi-ui.write_waypoint.v1 esi-characters.read_corporation_roles.v1 esi-location.read_online.v1 esi-characters.read_titles.v1 esi-search.search_structures.v1)
           |> Enum.join(" ")
       ]}
  ]

config :ueberauth, Ueberauth.Strategy.EVESSO.OAuth,
  client_id: {:system, "EVESSO_CLIENT_ID"},
  client_secret: {:system, "EVESSO_SECRET_KEY"}

config :tripwire, Tripwire.Mailer, adapter: Swoosh.Adapters.Local

config :tripwire,
  ecto_repos: [Tripwire.Repo],
  generators: [timestamp_type: :utc_datetime]

config :tripwire, Tripwire.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1", key: Base.decode64!("pd2umDJ8tuldw5vzB3bdUQnIK1cFI6FaHaNILBXCiUE=")
    }
  ]

config :tripwire, TripwireWeb.Endpoint,
  server: true,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TripwireWeb.ErrorHTML, json: TripwireWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tripwire.PubSub,
  live_view: [signing_salt: "2qoLjCJq"]

config :esbuild,
  version: "0.25.4",
  tripwire: [
    args: ~w(
      app=js/app.js
      dashboard=js/dashboard
      --bundle
      --target=es2022
      --outdir=../priv/static/assets/js
      --external:/fonts/*
      --external:/images/*
      --alias:@=.
      ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.1.12",
  tripwire: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
