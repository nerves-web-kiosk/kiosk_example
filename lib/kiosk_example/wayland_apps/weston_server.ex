defmodule KioskExample.WaylandApps.WestonServer do
  @moduledoc false
  use GenServer

  require Logger

  @spec start_link(map) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__, timeout: 15_000)
  end

  @spec stop() :: :ok
  def stop(), do: GenServer.stop(__MODULE__)

  @spec start_weston() :: :ok
  def start_weston(), do: GenServer.call(__MODULE__, :start)

  @spec stop_weston() :: :ok
  def stop_weston(), do: GenServer.call(__MODULE__, :stop)

  @spec restart_weston() :: :ok
  def restart_weston(), do: GenServer.call(__MODULE__, :restart)

  @spec restart_weston(String.t()) :: :ok
  def restart_weston(args), do: GenServer.call(__MODULE__, {:restart, args})

  @spec restart_weston(String.t(), [{String.t(), String.t()}]) :: :ok
  def restart_weston(args, env), do: GenServer.call(__MODULE__, {:restart, args, env})

  @impl GenServer
  def init(args) do
    Process.flag(:trap_exit, true)

    weston_args = Map.get(args, :weston_args, "--shell=kiosk --continue-without-input")
    weston_env = Map.get(args, :weston_env, [{"XDG_RUNTIME_DIR", "/run"}])

    wait_for_device("/dev/dri", ~r/^card[0-9]$/, _wait_time = 3000, _retry_count = 5)
    wait_for_device("/dev", ~r/^fb[0-9]$/, _wait_time = 3000, _retry_count = 5)

    {:ok,
     %{
       pid: start_weston(weston_args, weston_env),
       args: weston_args,
       env: weston_env
     }}
  end

  @impl GenServer
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

  @impl GenServer
  def handle_info({:EXIT, pid, reason}, state) when reason in [:killed] do
    Logger.debug("weston (#{inspect(pid)}) exited by #{inspect(reason)}.")
    {:noreply, state}
  end

  defp start_weston(args, env) do
    MuonTrap.Daemon.start_link("weston", ~w"#{args}",
      env: env,
      stderr_to_stdout: true,
      log_output: :debug,
      log_prefix: "weston: "
    )
    |> then(fn {:ok, pid} -> pid end)
  end

  defp wait_for_device(dir_path, device_name_regex, _wait_time, 0) do
    raise RuntimeError, "#{inspect(device_name_regex)} doesn't exist in #{dir_path}."
  end

  defp wait_for_device(dir_path, device_name_regex, wait_time, retry_count)
       when retry_count > 0 do
    if device_exists?(dir_path, device_name_regex) do
      Logger.debug("Found #{inspect(device_name_regex)} in #{dir_path}.")
    else
      Process.sleep(wait_time)
      wait_for_device(dir_path, device_name_regex, wait_time, retry_count - 1)
    end
  end

  defp device_exists?(dir_path, regex) do
    case File.ls(dir_path) do
      {:ok, files} -> Enum.any?(files, &String.match?(&1, regex))
      {:error, _reason} -> false
    end
  end
end
