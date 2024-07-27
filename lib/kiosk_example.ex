defmodule KioskExample do
  @moduledoc """
  Documentation for `KioskExample`.
  """

  def live_dashboard() do
    change_url("http://localhost:4000/dev/dashboard/home/")
  end

  def phoenix_home() do
    change_url("http://localhost:4000/")
  end

  def nerves_project_org() do
    change_url("https://nerves-project.org/")
  end

  def phoenixframework_org() do
    change_url("https://www.phoenixframework.org/")
  end

  def jerry_fish() do
    change_url("https://akirodic.com/p/jellyfish/")
  end

  def change_url(url) do
    KioskExample.WaylandApps.CogServer.restart_cog("--platform=wl #{url}")
  end
end
