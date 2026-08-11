defmodule KioskDemo.KioskSupervisor do
  @moduledoc false
  use Supervisor

  @runtime_dir "/run"
  @wayland_display "wayland-1"
  @poll_ms 500
  @max_retries 20
  @drm_dir "/dev/dri"
  @drm_card_pattern ~r/^card[0-9]$/
  @dbus_socket_path "/run/dbus-session-bus"
  @dbus_session_bus_address "unix:path=#{@dbus_socket_path}"

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    configure_dbus_session_bus()

    weston_env = [{"XDG_RUNTIME_DIR", @runtime_dir}]

    cog_env =
      [
        {"XDG_RUNTIME_DIR", @runtime_dir},
        {"WAYLAND_DISPLAY", @wayland_display},
        {"DBUS_SESSION_BUS_ADDRESS", @dbus_session_bus_address}
      ] ++ Myelin.browser_env()

    wayland_socket = Path.join(@runtime_dir, @wayland_display)

    children = [
      Supervisor.child_spec(
        {MuonTrap.Daemon,
         [
           "dbus-daemon",
           [
             "--session",
             "--address=#{@dbus_session_bus_address}",
             "--nofork",
             "--syslog-only"
           ],
           [
             stderr_to_stdout: true,
             log_output: :info,
             log_prefix: "dbus: "
           ]
         ]},
        id: :dbus
      ),
      Supervisor.child_spec(
        {MuonTrap.Daemon,
         [
           "weston",
           ["--shell=kiosk", "--continue-without-input"],
           [
             env: weston_env,
             stderr_to_stdout: true,
             log_output: :info,
             log_prefix: "weston: ",
             wait_for: fn -> wait_for_match(@drm_dir, @drm_card_pattern) end
           ]
         ]},
        id: :weston
      ),
      Supervisor.child_spec(
        {MuonTrap.Daemon,
         [
           "cog",
           ["--platform=wl", "http://localhost:4000/"] ++ Myelin.browser_args(),
           [
             env: cog_env,
             stderr_to_stdout: true,
             log_output: :info,
             log_prefix: "cog: ",
             wait_for: fn ->
               wait_for_path(@dbus_socket_path)
               wait_for_path(wayland_socket)
             end
           ]
         ]},
        id: :cog
      )
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # The :dbus library defaults the EXTERNAL SASL "cookie" to UID 1000; on Nerves
  # we run as root (UID 0). Also point the BEAM at the socket dbus-daemon is
  # about to serve on so :dbus clients reach the same bus as cog.
  defp configure_dbus_session_bus() do
    System.put_env("DBUS_SESSION_BUS_ADDRESS", @dbus_session_bus_address)
    Application.put_env(:dbus, :external_cookie, external_auth_cookie())
  end

  defp external_auth_cookie() do
    uid()
    |> Integer.to_string()
    |> Base.encode16(case: :lower)
  end

  defp uid() do
    with {:ok, content} <- File.read("/proc/self/status"),
         [_, uid] <- Regex.run(~r/^Uid:\s+(\d+)/m, content) do
      String.to_integer(uid)
    else
      _ -> 0
    end
  end

  defp wait_for_path(path, retries \\ @max_retries)

  defp wait_for_path(path, 0),
    do: raise(RuntimeError, "#{path} did not appear in time")

  defp wait_for_path(path, retries) do
    if File.exists?(path) do
      :ok
    else
      Process.sleep(@poll_ms)
      wait_for_path(path, retries - 1)
    end
  end

  defp wait_for_match(dir, regex, retries \\ @max_retries)

  defp wait_for_match(dir, regex, 0),
    do: raise(RuntimeError, "no entry matching #{inspect(regex)} appeared in #{dir}")

  defp wait_for_match(dir, regex, retries) do
    case File.ls(dir) do
      {:ok, files} ->
        if Enum.any?(files, &Regex.match?(regex, &1)) do
          :ok
        else
          Process.sleep(@poll_ms)
          wait_for_match(dir, regex, retries - 1)
        end

      {:error, _} ->
        Process.sleep(@poll_ms)
        wait_for_match(dir, regex, retries - 1)
    end
  end
end
