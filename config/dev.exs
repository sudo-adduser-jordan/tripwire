import Config

config :ztripwire, Ztripwire.Repo,
  database:
    (case System.get_env("DATABASE_PATH") do
       path when path in [nil, ""] -> Path.expand("../priv/db/ztripwire-dev.db", __DIR__)
       path -> path
     end),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  journal_mode: :wal,
  busy_timeout: 5000

config :ztripwire, Ztripwire.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1", key: Base.decode64!("u2KOwkvRL9KJwyer7hu1+QYL89dFoMWivjrj+UNnd3I=")
    }
  ]

secret_key_base =
  case System.get_env("PHX_SECRET_KEY_BASE") do
    value when value in [nil, ""] ->
      "d6Em9Z/PYa9kQOeMPRR/ChECGgNrfYgyGu61Rji27OuX/XAsGgxPDe0tIYyx8djf"

    value ->
      value
  end

config :ztripwire, ZtripwireWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: secret_key_base,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:ztripwire, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:ztripwire, ~w(--watch)]}
  ]

config :ztripwire, ZtripwireWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/gettext/.*\.po$",
      ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"web/(controllers|live|components|router|widgets|RootLayout|pages|views)/.*\.(ex|heex)$"
    ]
  ]

config :swoosh, :api_client, false

config :ztripwire, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
