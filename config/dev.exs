import Config

config :tripwire, Tripwire.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tripwire_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :tripwire, TripwireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "vMF19d7PFCEnoNpB3YLYvvB6tdFNlj/Hp7UgubbvgYsmhmztIDM/GtMMscbKlBds",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:tripwire, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:tripwire, ~w(--watch)]}
  ]

config :tripwire, TripwireWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
      ~r"priv/gettext/.*\.po$"E,
      ~r"lib/tripwire_web/router\.ex$"E,
      ~r"lib/tripwire_web/(controllers|live|components)/.*\.(ex|heex)$"E
    ]
  ]

config :swoosh, :api_client, false
config :tripwire, dev_routes: true
config :logger, :default_formatter, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
