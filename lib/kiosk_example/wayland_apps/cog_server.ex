defmodule KioskExample.WaylandApps.CogServer do
  use GenServer

  require Logger

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def stop(), do: GenServer.stop(__MODULE__)

  def start_cog(), do: GenServer.call(__MODULE__, :start)
  def stop_cog(), do: GenServer.call(__MODULE__, :stop)
  def restart_cog(), do: GenServer.call(__MODULE__, :restart)
  def restart_cog(args), do: GenServer.call(__MODULE__, {:restart, args})
  def restart_cog(args, env), do: GenServer.call(__MODULE__, {:restart, args, env})

  def init(args) do
    Process.flag(:trap_exit, true)

    cog_args = Map.get(args, :cog_args, "--platform=wl http://localhost:4000/dev/dashboard/home")

    cog_env =
      Map.get(args, :cog_env, [{"XDG_RUNTIME_DIR", "/run"}, {"WAYLAND_DISPLAY", "wayland-1"}])

    {:ok,
     %{
       pid: start_cog(cog_args, cog_env),
       args: cog_args,
       env: cog_env
     }}
  end

  def terminate(reason, state) do
    Process.exit(state.pid, :kill)
    Logger.debug("#{__MODULE__} terminated by #{inspect(reason)}.")
  end

  def handle_call(:start, _from, state) do
    {:reply, :ok, %{state | pid: start_cog(state.args, state.env)}}
  end

  def handle_call(:stop, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, state}
  end

  def handle_call(:restart, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_cog(state.args, state.env)}}
  end

  def handle_call({:restart, args}, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_cog(args, state.env), args: args}}
  end

  def handle_call({:restart, args, env}, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_cog(args, env), args: args, env: env}}
  end

  def handle_info({:EXIT, pid, reason}, state) when reason in [:killed] do
    Logger.debug("cog (#{inspect(pid)}) exited by #{inspect(reason)}.")
    {:noreply, state}
  end

  defp start_cog(args, env) do
    MuonTrap.Daemon.start_link("cog", ~w"#{args}",
      env: env,
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "cog: "
    )
    |> then(fn {:ok, pid} -> pid end)
  end
end
