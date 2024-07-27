defmodule KioskExample.WaylandApps.WestonServer do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__, timeout: 15_000)
  end

  def stop(), do: GenServer.stop(__MODULE__)

  def start_weston(), do: GenServer.call(__MODULE__, :start)
  def stop_weston(), do: GenServer.call(__MODULE__, :stop)
  def restart_weston(), do: GenServer.call(__MODULE__, :restart)
  def restart_weston(args), do: GenServer.call(__MODULE__, {:restart, args})
  def restart_weston(args, env), do: GenServer.call(__MODULE__, {:restart, args, env})

  def init(args) do
    Process.flag(:trap_exit, true)

    weston_args = Map.get(args, :weston_args, "--shell=kiosk --continue-without-input")
    weston_env = Map.get(args, :weston_env, [{"XDG_RUNTIME_DIR", "/run"}])

    wait_for_device("/dev/dri", "^card[0-9]$", _wait_time = 3000, _retry_count = 5)
    wait_for_device("/dev", "^fb[0-9]$", _wait_time = 3000, _retry_count = 5)

    {:ok,
     %{
       pid: start_weston(weston_args, weston_env),
       args: weston_args,
       env: weston_env
     }}
  end

  def terminate(reason, state) do
    Process.exit(state.pid, :kill)
    Logger.debug("#{__MODULE__} terminated by #{inspect(reason)}.")
  end

  def handle_call(:start, _from, state) do
    {:reply, :ok, %{state | pid: start_weston(state.args, state.env)}}
  end

  def handle_call(:stop, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, state}
  end

  def handle_call(:restart, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_weston(state.args, state.env)}}
  end

  def handle_call({:restart, args}, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_weston(args, state.env), args: args}}
  end

  def handle_call({:restart, args, env}, _from, state) do
    Process.exit(state.pid, :kill)
    {:reply, :ok, %{state | pid: start_weston(args, env), args: args, env: env}}
  end

  def handle_info({:EXIT, pid, reason}, state) when reason in [:killed] do
    Logger.debug("weston (#{inspect(pid)}) exited by #{inspect(reason)}.")
    {:noreply, state}
  end

  defp start_weston(args, env) do
    spawn_link(fn ->
      MuonTrap.cmd("weston", ~w"#{args}",
        env: env,
        stderr_to_stdout: true,
        into: IO.stream(:stdio, :line)
      )
    end)
  end

  defp wait_for_device(dir_path, file_name, _wait_time, 0) do
    raise RuntimeError, "#{file_name} doesn't exist in #{dir_path}."
  end

  defp wait_for_device(dir_path, file_name, wait_time, retry_count) when retry_count > 0 do
    if device_exists?(dir_path, file_name) do
      Logger.debug("#{file_name} exists in #{dir_path}.")
    else
      Process.sleep(wait_time)
      wait_for_device(dir_path, file_name, wait_time, retry_count - 1)
    end
  end

  defp device_exists?(dir_path, file_name) do
    case File.ls(dir_path) do
      {:ok, files} -> Enum.any?(files, &String.match?(&1, ~r/#{file_name}/))
      {:error, _reason} -> false
    end
  end
end
