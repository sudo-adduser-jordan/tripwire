import Config

if System.get_env("PHX_SERVER") do
  config :tripwire, TripwireWeb.Endpoint, server: true
end

config :tripwire, TripwireWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      Set it to the SQLite database file on a persistent volume.
      For example: /data/tripwire-prod.db
      """

  config :tripwire, Tripwire.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    journal_mode: :wal,
    busy_timeout: 5000

  encryption_key =
    System.get_env("TRIPWIRE_ENCRYPTION_KEY") ||
      raise """
      environment variable TRIPWIRE_ENCRYPTION_KEY is missing.
      Generate one with: openssl rand -base64 32
      """

  config :tripwire, Tripwire.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(encryption_key)}
    ]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :tripwire, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :tripwire, TripwireWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
