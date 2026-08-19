defmodule GovSim.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GovSimWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:gov_sim, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GovSim.PubSub},
      GovSim.Simulation.Engine,
      # Start to serve requests, typically the last entry
      GovSimWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GovSim.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GovSimWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
