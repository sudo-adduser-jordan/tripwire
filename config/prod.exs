import Config

config :ztripwire, ZtripwireWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"

config :ztripwire, secure_session: true

config :ztripwire, ZtripwireWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto]]
config :phoenix, :plug_init_mode, :runtime
config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false
config :logger, level: :info
