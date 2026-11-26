import Config

if System.get_env("PHX_SERVER") do
  config :ztripwire, ZtripwireWeb.Endpoint, server: true
end

config :ztripwire, ZtripwireWeb.Endpoint,
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
    For example: /data/ztripwire-prod.db
    """
  end

  config :ztripwire, Ztripwire.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    journal_mode: :wal,
    busy_timeout: 5000

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :ztripwire, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ztripwire, ZtripwireWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: [
      "https://#{host}",
      "http://localhost:#{port}",
      "http://127.0.0.1:#{port}"
    ],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ]
end
