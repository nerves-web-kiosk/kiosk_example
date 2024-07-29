defmodule KioskExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: KioskExample.Worker.start_link(arg)
        # {KioskExample.Worker, arg},
      ] ++ phoenix_children() ++ children(Nerves.Runtime.mix_target())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KioskExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  defp children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: KioskExample.Worker.start_link(arg)
      # {KioskExample.Worker, arg},
    ]
  end

  defp children(_target) do
    # NOTE: work around to stop watchers on targets
    Application.get_env(:kiosk_example, KioskExampleWeb.Endpoint)
    |> Keyword.put(:watchers, [])
    |> then(&Application.put_env(:kiosk_example, KioskExampleWeb.Endpoint, &1))

    start_node()

    [
      # Children for all targets except host
      # Starts a worker by calling: KioskExample.Worker.start_link(arg)
      # {KioskExample.Worker, arg},
      {KioskExample.DisplaySupervisor, %{}}
    ]
  end

  defp phoenix_children() do
    [
      KioskExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:kiosk_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KioskExample.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: KioskExample.Finch},
      # Start a worker by calling: KioskExample.Worker.start_link(arg)
      # {KioskExample.Worker, arg},
      # Start to serve requests, typically the last entry
      KioskExampleWeb.Endpoint
    ]
  end

  defp start_node() do
    System.cmd("epmd", ~w"-daemon")
    Node.start(:"kiosk_example@nerves.local")
    Node.set_cookie(Application.get_env(:mix_tasks_upload_hotswap, :cookie))
  end
end
