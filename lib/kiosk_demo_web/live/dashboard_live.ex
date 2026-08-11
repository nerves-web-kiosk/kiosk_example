defmodule KioskDemoWeb.DashboardLive do
  use KioskDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("myelin:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col relative">
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
