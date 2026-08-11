defmodule KioskDemo.SystemMetrics do
  @moduledoc """
  System-level metrics (CPU, memory, load average).

  `sample/0` returns the current measurements directly; `measure/0` emits
  them as a `[:kiosk_demo, :system]` telemetry event for the telemetry
  poller and LiveDashboard.
  """

  @event_name [:kiosk_demo, :system]

  @type sample :: %{
          cpu_util: float(),
          memory_used_bytes: non_neg_integer(),
          load_avg_1: float()
        }

  @spec event_name() :: [:kiosk_demo | :system, ...]
  def event_name(), do: @event_name

  @doc "Current system measurements as a plain map."
  @spec sample() :: sample()
  def sample() do
    %{
      cpu_util: cpu_util(),
      memory_used_bytes: :erlang.memory(:total),
      load_avg_1: load_avg_1()
    }
  end

  @spec measure() :: :ok
  def measure() do
    :telemetry.execute(@event_name, sample(), %{})
  end

  defp load_avg_1() do
    case :cpu_sup.avg1() do
      n when is_number(n) -> n / 256
      {:error, _} -> 0.0
    end
  end

  defp cpu_util() do
    case :cpu_sup.util() do
      n when is_number(n) -> n * 1.0
      {:error, _} -> 0.0
    end
  end
end
