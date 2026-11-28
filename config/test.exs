import Config

config :ztripwire, Ztripwire.Repo,
  database: Path.expand("../priv/db/ztripwire-test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  journal_mode: :wal,
  busy_timeout: 5000

secret_key_base =
  case System.get_env("PHX_SECRET_KEY_BASE") do
    value when value in [nil, ""] ->
      "8nwSJ80OFl6XkdKMV0Q/wsYTQ6W5inMjGlvXAy/T+dISRRj59zttctVr7Vh+gRU8"

    value ->
      value
  end

config :ztripwire, ZtripwireWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: secret_key_base,
  server: false

config :ztripwire, Ztripwire.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1", key: Base.decode64!("u2KOwkvRL9KJwyer7hu1+QYL89dFoMWivjrj+UNnd3I=")
    }
  ]

config :ztripwire, Ztripwire.Systems.Catalog, path: nil
config :ztripwire, Ztripwire.Systems.Gates, path: nil
config :ztripwire, Ztripwire.SyncServer, prune_on_start: false
config :ztripwire, Ztripwire.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false
config :ztripwire, :topbar_esi, false
config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true
