defmodule KioskExample.UdevdServer do
  use GenServer

  require Logger

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(_args) do
    Process.flag(:trap_exit, true)

    pid = start_udev("", [])

    udevadm("trigger --type=subsystems --action=add")
    udevadm("trigger --type=devices --action=add")
    udevadm("settle --timeout=30")

    {:ok, %{pid: pid}}
  end

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
    spawn_link(fn ->
      MuonTrap.cmd("udevd", ~w"#{args}",
        env: env,
        stderr_to_stdout: true,
        into: IO.stream(:stdio, :line)
      )
    end)
  end

  defp udevadm(args) do
    MuonTrap.cmd("udevadm", ~w"#{args}",
      stderr_to_stdout: true,
      into: IO.stream(:stdio, :line)
    )
  end
end
