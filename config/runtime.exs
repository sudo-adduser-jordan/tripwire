import Config

if System.get_env("PHX_SERVER") do
  config :tripwire, TripwireWeb.Endpoint, server: true
end

config :tripwire, TripwireWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if sso_secret = System.get_env("EVESSO_SECRET_KEY") || System.get_env("EVESSO_CLIENT_SECRET") do
  config :ueberauth, Ueberauth.Strategy.EVESSO.OAuth, client_secret: sso_secret
end

if config_env() == :prod do
  database_path = System.get_env("DATABASE_PATH")

  if database_path in [nil, ""] do
    raise """
    environment variable DATABASE_PATH is missing.
    Set it to the SQLite database file on a persistent volume.
    For example: /data/tripwire-prod.db
    """
  end

  config :tripwire, Tripwire.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    journal_mode: :wal,
    busy_timeout: 5000

  host = System.get_env("PHX_HOST") || "example.com"

  config :tripwire, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :tripwire, TripwireWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ]
end
