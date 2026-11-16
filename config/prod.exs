import Config

config :tripwire, TripwireWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: "vMF19d7PFCEnoNpB3YLYvvB6tdFNlj/Hp7UgubbvgYsmhmztIDM/GtMMscbKlBds"

config :tripwire, TripwireWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto]]
config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false
config :logger, level: :info
