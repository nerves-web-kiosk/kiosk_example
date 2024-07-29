defmodule KioskExample.DisplaySupervisor do
  @moduledoc false
  use Supervisor

  alias KioskExample.UdevdServer
  alias KioskExample.WaylandAppsSupervisor

  @spec start_link(map()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      {UdevdServer, %{}},
      {WaylandAppsSupervisor, %{}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
