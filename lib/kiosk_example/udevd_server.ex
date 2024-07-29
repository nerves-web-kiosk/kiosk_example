defmodule KioskExample.UdevdServer do
  @moduledoc false
  use GenServer

  require Logger

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl GenServer
  def init(_args) do
    Process.flag(:trap_exit, true)

    pid = start_udev("", [])

    udevadm("trigger --type=subsystems --action=add")
    udevadm("trigger --type=devices --action=add")
    udevadm("settle --timeout=30")

    {:ok, %{pid: pid}}
  end

  @impl GenServer
  def handle_info({:EXIT, pid, reason}, state) do
    if pid == state.pid do
      Logger.error("udevd (#{inspect(pid)}) exited by #{inspect(reason)}.")
      {:stop, :unexpected, state}
    else
      Logger.debug("udevadm (#{inspect(pid)}) exited by #{inspect(reason)}.")
      {:noreply, state}
    end
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

  defp udevadm(args) do
    MuonTrap.cmd("udevadm", ~w"#{args}",
      stderr_to_stdout: true,
      into: IO.stream(:stdio, :line)
    )
  end
end
