defmodule CrewPoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CrewPocWeb.Telemetry,
      CrewPoc.Repo,
      {DNSCluster, query: Application.get_env(:crew_poc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CrewPoc.PubSub},
      # Start a worker by calling: CrewPoc.Worker.start_link(arg)
      # {CrewPoc.Worker, arg},
      # Start to serve requests, typically the last entry
      CrewPocWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CrewPoc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CrewPocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
