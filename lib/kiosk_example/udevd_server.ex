defmodule KioskExample.UdevdServer do
  @moduledoc false
  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @spec udevadm(String.t()) :: {Collectable.t(), exit_status :: non_neg_integer()}
  def udevadm(args) do
    System.shell("udevadm #{args}", stderr_to_stdout: true, into: IO.stream(:stdio, :line))
  end

  @impl GenServer
  def init(_args) do
    pid = start_udev("", [])

    {_, 0} = udevadm("trigger --type=subsystems --action=add")
    {_, 0} = udevadm("trigger --type=devices --action=add")
    {_, 0} = udevadm("settle --timeout=30")

    {:ok, %{pid: pid}}
  end

  defp start_udev(args, env) do
    MuonTrap.Daemon.start_link("udevd", ~w"#{args}",
      env: env,
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "udevd: "
    )
    |> then(fn {:ok, pid} -> pid end)
  end
end
