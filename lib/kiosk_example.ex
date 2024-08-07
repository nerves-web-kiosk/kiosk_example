defmodule KioskExample do
  @moduledoc """
  Collection of functions to control the browser
  """
  alias KioskExample.WaylandApps.CogServer

  @doc """
  Go to the main page
  """
  @spec home() :: :ok
  def home() do
    change_url("http://localhost:4000/")
  end

  @doc """
  Go to the gpio page
  """
  @spec gpio() :: :ok
  def gpio() do
    change_url("http://localhost:4000/gpio")
  end

  @doc """
  Go to the Phoenix LiveDashboard
  """
  @spec live_dashboard() :: :ok
  def live_dashboard() do
    change_url("http://localhost:4000/dev/dashboard/home/")
  end

  @doc """
  Go to the Nerves home page
  """
  @spec nerves_project_org() :: :ok
  def nerves_project_org() do
    change_url("https://nerves-project.org/")
  end

  @doc """
  Go to the Phoenix Framework home page
  """
  @spec phoenixframework_org() :: :ok
  def phoenixframework_org() do
    change_url("https://www.phoenixframework.org/")
  end

  @doc """
  Show a jellyfish animation
  """
  @spec jellyfish() :: :ok
  def jellyfish() do
    change_url("https://akirodic.com/p/jellyfish/")
  end

  @doc """
  Change to the specified URL
  """
  @spec change_url(String.t()) :: :ok
  def change_url(url) when is_binary(url) do
    CogServer.restart_cog("--platform=wl #{url}")
  end
end
