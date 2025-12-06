import Config

config :tripwire, Tripwire.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tripwire_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

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
