defmodule KioskExampleWeb.GPIOLive do
  @moduledoc """
  This implementation is very lazy.
  Idiomatically the HW logic should be located in `KioskExample` side and
  for local development, we should use like [mox](https://github.com/dashbitco/mox) things.
  """

  use KioskExampleWeb, :live_view

  def render(assigns) do
    ~H"""
    <div id="gpio-button-list" class="grid grid-rows-10 grid-flow-col gap-4">
      <%= for %{label: label} <- enumerate_gpio() do %>
        <button
          class={["p-3 rounded-md", bg_color(Map.get(@gpios, label))]}
          phx-click="push"
          value={label}
        >
          <%= label %>
        </button>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    initial_value = 0

    gpios =
      for %{label: label} <- enumerate_gpio(), into: %{} do
        :ok = write_gpio(label, initial_value)
        {label, initial_value}
      end

    {:ok, assign(socket, :gpios, gpios)}
  end

  def handle_event("push", %{"value" => label}, socket) do
    gpios = socket.assigns.gpios
    value = Map.get(gpios, label) |> Bitwise.bxor(1)

    :ok = write_gpio(label, value)

    {:noreply, assign(socket, :gpios, Map.put(gpios, label, value))}
  end

  if Mix.target() == :host do
    defp enumerate_gpio() do
      2..27
      |> Enum.map(&%{label: "GPIO#{&1}"})
      |> reject_already_used_gpios()
    end

    defp write_gpio(_label, _value) do
      :ok
    end
  else
    defp enumerate_gpio() do
      Circuits.GPIO.enumerate()
      |> Enum.filter(fn %{label: label} -> String.starts_with?(label, "GPIO") end)
      |> reject_already_used_gpios()
    end

    defp write_gpio(label, value) do
      Circuits.GPIO.write_one(label, value)
    end
  end

  defp reject_already_used_gpios(gpios) do
    Enum.reject(gpios, fn %{label: label} -> label in ["GPIO7", "GPIO8"] end)
  end

  defp bg_color(0), do: "bg-gray-200"
  defp bg_color(1), do: "bg-amber-300"
end
