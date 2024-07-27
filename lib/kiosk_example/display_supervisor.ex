defmodule KioskExample.DisplaySupervisor do
  use Supervisor

  alias KioskExample.UdevdServer
  alias KioskExample.WaylandAppsSupervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {UdevdServer, %{}},
      {WaylandAppsSupervisor, %{}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
