defmodule ParserTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParserTestWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:parser_test, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ParserTest.PubSub},
      # Start a worker by calling: ParserTest.Worker.start_link(arg)
      # {ParserTest.Worker, arg},
      # Start to serve requests, typically the last entry
      ParserTestWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ParserTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ParserTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
