import Config

config :tripwire, Ueberauth,
  providers: [
    auth0: {Ueberauth.Strategy.Auth0, [otp_app: :tripwire]}
  ]

config :tripwire, Ueberauth.Strategy.Auth0.OAuth,
  domain: System.get_env("AUTH0_DOMAIN"),
  client_id: System.get_env("AUTH0_CLIENT_ID"),
  client_secret: System.get_env("AUTH0_CLIENT_SECRET")

config :tripwire, Tripwire.Mailer, adapter: Swoosh.Adapters.Local

config :tripwire,
  ecto_repos: [Tripwire.Repo],
  generators: [timestamp_type: :utc_datetime]

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
    args:
      ~w(
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
