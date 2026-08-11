defmodule KioskDemoWeb.Live.Screensaver do
  @moduledoc """
  Provides screensaver functionality for LiveView pages.

  ## Usage

  Add `use KioskDemoWeb.Live.Screensaver` to your LiveView module,
  then call the helpers in your mount/render functions:

      defmodule MyLive do
        use KioskDemoWeb, :live_view
        use KioskDemoWeb.Live.Screensaver

        def mount(_params, _session, socket) do
          {:ok, init_screensaver(socket)}
        end

        def render(assigns) do
          ~H\"\"\"
          <div {screensaver_events()}>
            <.screensaver_overlay active={@screensaver_active} />
            <!-- your content -->
          </div>
          \"\"\"
        end
      end
  """

  @idle_timeout 60_000

  defmacro __using__(_opts) do
    quote do
      import KioskDemoWeb.Live.Screensaver,
        only: [init_screensaver: 1, screensaver_events: 0]

      def handle_event("user_activity", _params, socket) do
        {:noreply, KioskDemoWeb.Live.Screensaver.handle_user_activity(socket)}
      end

      def handle_info(:check_idle, socket) do
        {:noreply, KioskDemoWeb.Live.Screensaver.handle_idle_check(socket)}
      end
    end
  end

  @doc """
  Initializes screensaver state in the socket.

  Call this in your `mount/3` callback.
  """
  @spec init_screensaver(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def init_screensaver(socket) do
    if Phoenix.LiveView.connected?(socket) do
      schedule_idle_check()
    end

    socket
    |> Phoenix.Component.assign(:screensaver_active, false)
    |> Phoenix.Component.assign(:last_activity, System.monotonic_time(:millisecond))
  end

  @doc """
  Returns the event attributes for screensaver user activity tracking.

  Add these to your top-level container element.
  """
  @spec screensaver_events() :: keyword()
  def screensaver_events do
    [
      "phx-click": "user_activity",
      "phx-window-keydown": "user_activity",
      "phx-window-mousemove": "user_activity",
      "phx-window-touchstart": "user_activity",
      "phx-throttle": "1000"
    ]
  end

  @doc false
  def handle_user_activity(socket) do
    current_time = System.monotonic_time(:millisecond)

    if socket.assigns.screensaver_active do
      Phoenix.Component.assign(socket,
        screensaver_active: false,
        last_activity: current_time
      )
    else
      Phoenix.Component.assign(socket, last_activity: current_time)
    end
  end

  @doc false
  def handle_idle_check(socket) do
    current_time = System.monotonic_time(:millisecond)
    idle_time = current_time - socket.assigns.last_activity

    socket =
      if idle_time >= @idle_timeout and not socket.assigns.screensaver_active do
        Phoenix.Component.assign(socket, screensaver_active: true)
      else
        socket
      end

    schedule_idle_check()
    socket
  end

  defp schedule_idle_check do
    _ = Process.send_after(self(), :check_idle, 1000)
    :ok
  end
end
