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

    wait_for_display(cog_args, cog_env, _wait_time = 1000, _retry_count = 3)

    {:ok,
     %{
       pid: start_cog(cog_args, cog_env),
       args: cog_args,
       env: cog_env
     }}
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

  defp wait_for_display(args, env, wait_time, retry_count) do
    cond do
      String.contains?(args, "--platform=wl") ->
        xdg_runtime_dir = get_env_value(env, "XDG_RUNTIME_DIR")
        wayland_display = get_env_value(env, "WAYLAND_DISPLAY")
        wait_for_device(xdg_runtime_dir, ~r/^#{wayland_display}$/, wait_time, retry_count)

      true ->
        :noop
    end
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

  defp get_env_value(env, key) when is_list(env) do
    value = Enum.find_value(env, fn {k, v} -> if k == key, do: v end)

    if is_nil(value) do
      raise RuntimeError, "#{key} must be set for cog."
    end

    value
  end
end
