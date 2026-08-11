defmodule KioskDemoWeb.DashboardLive do
  use KioskDemoWeb, :live_view
  use KioskDemoWeb.Live.Screensaver

  def mount(_params, _session, socket) do
    {:ok, init_screensaver(socket)}
  end

  def render(assigns) do
    ~H"""
    <div {screensaver_events()} class="h-screen flex flex-col relative">
      <.screensaver_overlay active={@screensaver_active} />

      <div class="bg-base-200 border-b border-base-300 px-4 py-3 flex items-center gap-3">
        <a href="/" class="btn btn-sm btn-primary gap-2">
          <.icon name="hero-home" class="size-4" /> Home
        </a>
        <span class="text-lg font-semibold">Phoenix LiveDashboard</span>
      </div>
      <div class="flex-1 overflow-hidden">
        <iframe src="/dev/dashboard" class="w-full h-full border-0"></iframe>
      </div>
    </div>
    """
  end
end
