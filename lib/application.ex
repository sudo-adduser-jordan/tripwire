defmodule Ztripwire.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZtripwireWeb.Telemetry,
      Ztripwire.Repo,
      Ztripwire.Vault,
      Ztripwire.ESI.TokenCache,
      Ztripwire.Systems.Catalog,
      Ztripwire.Systems.Gates,
      {Phoenix.PubSub, name: Ztripwire.PubSub},
      Ztripwire.Tracking.PollerSupervisor,
      {Registry, keys: :unique, name: Ztripwire.TrackingRegistry},
      Ztripwire.SyncServer,
      {DNSCluster, query: Application.get_env(:ztripwire, :dns_cluster_query) || :ignore},
      ZtripwireWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Ztripwire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ZtripwireWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
