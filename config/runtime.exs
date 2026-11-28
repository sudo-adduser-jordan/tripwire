import Config

if System.get_env("PHX_SERVER") do
  config :ztripwire, ZtripwireWeb.Endpoint, server: true
end

config :ztripwire, ZtripwireWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if sso_secret = System.get_env("EVESSO_CLIENT_SECRET") || System.get_env("EVESSO_SECRET_KEY") do
  config :ueberauth, Ueberauth.Strategy.EVESSO.OAuth, client_secret: sso_secret
end

if callback_url = System.get_env("EVESSO_CALLBACK_URL") do
  providers =
    :ueberauth
    |> Application.get_env(Ueberauth, [])
    |> Keyword.get(:providers, [])
    |> Keyword.update(:evesso, nil, fn {module, opts} ->
      {module, Keyword.put(opts, :callback_url, callback_url)}
    end)

  if providers do
    config :ueberauth, Ueberauth, providers: providers
  end
end

esi_user_agent = System.get_env("ZTRIPWIRE_USER_AGENT")
esi_compatibility_date = System.get_env("ZTRIPWIRE_ESI_COMPATIBILITY_DATE")

if esi_user_agent do
  config :ztripwire, Ztripwire.ESI, user_agent: esi_user_agent
end

if esi_compatibility_date do
  config :ztripwire, Ztripwire.ESI, compatibility_date: esi_compatibility_date
end

cloak_key =
  case System.get_env("ZTRIPWIRE_CLOAK_KEY") do
    value when value in [nil, ""] -> nil
    value -> value
  end

if cloak_key do
  config :ztripwire, Ztripwire.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1", key: Base.decode64!(cloak_key)
      }
    ]
end

if config_env() == :prod do
  cloak_key = System.get_env("ZTRIPWIRE_CLOAK_KEY")

  if cloak_key in [nil, ""] do
    raise """
    environment variable ZTRIPWIRE_CLOAK_KEY is missing.
    Set it to the base64-encoded 32-byte key used to encrypt ESI refresh tokens.
    For example: openssl rand -base64 32
    """
  end

  secret_key_base = System.get_env("PHX_SECRET_KEY_BASE")

  if secret_key_base in [nil, ""] do
    raise """
    environment variable PHX_SECRET_KEY_BASE is missing.
    Generate one with: mix phx.gen.secret
    """
  end

  config :ztripwire, ZtripwireWeb.Endpoint, secret_key_base: secret_key_base

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
