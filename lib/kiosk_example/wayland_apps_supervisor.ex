defmodule KioskExample.WaylandAppsSupervisor do
  use Supervisor

  alias KioskExample.WaylandApps

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {WaylandApps.WestonServer, %{}},
      {WaylandApps.CogServer, %{}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
