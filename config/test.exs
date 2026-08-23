import Config

config :tripwire, Tripwire.Repo,
  database: Path.expand("../priv/db/tripwire-test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  journal_mode: :wal,
  busy_timeout: 5000

config :tripwire, TripwireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "oRmSSMd12xHQZCytekL1JqwYNt5SvFEvz4TUqidiRwOjk8odehw2oxVq8kwp9C8g",
  server: false

config :tripwire, Tripwire.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
