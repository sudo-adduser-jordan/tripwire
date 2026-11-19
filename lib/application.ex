defmodule Tripwire.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TripwireWeb.Telemetry,
      Tripwire.Repo,
      Tripwire.Vault,
      Tripwire.ESI.TokenCache,
      {Phoenix.PubSub, name: Tripwire.PubSub},
      Tripwire.Tracking.PollerSupervisor,
      {Registry, keys: :unique, name: Tripwire.TrackingRegistry},
      Tripwire.SyncServer,
      {DNSCluster, query: Application.get_env(:tripwire, :dns_cluster_query) || :ignore},
      TripwireWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Tripwire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TripwireWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
