defmodule KioskDemoWeb.GPIOLive do
  @moduledoc """
  View and control GPIOs
  """

  use KioskDemoWeb, :live_view

  alias Circuits.GPIO

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-slate-50">
      <div class="bg-white border-b border-slate-200 px-4 py-3 flex items-center gap-3 shadow-sm">
        <a href="/" class="btn btn-sm btn-primary gap-2">
          <.icon name="hero-home" class="size-4" /> Home
        </a>
        <span class="text-lg font-semibold text-slate-800">GPIO Control</span>
      </div>

      <div class="px-4 py-6 overflow-auto">
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div class="flex items-start gap-3">
            <.icon name="hero-information-circle" class="size-5 text-blue-600 mt-0.5 flex-shrink-0" />
            <div class="text-sm text-blue-900">
              <p class="font-semibold mb-1">GPIO Control Panel</p>
              <p>
                Select GPIOs to open, configure them as input or output, and control their state.
                Set pull mode for inputs (pull-up, pull-down, or none) and toggle outputs between LOW and HIGH.
                All GPIOs are automatically released when you navigate away from this page.
              </p>
            </div>
          </div>
        </div>

        <%= if map_size(@open_gpios) > 0 do %>
          <div class="mb-6">
            <h2 class="text-lg font-bold text-slate-800 mb-4">
              <.icon name="hero-cpu-chip" class="size-5 inline" />
              Opened GPIOs ({map_size(@open_gpios)})
            </h2>

            <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
              <%= for {label, gpio_state} <- @open_gpios do %>
                <% display = display_name(label, gpio_state.location) %>
                <div class="bg-white border-2 border-blue-400 rounded-lg p-4 shadow-md">
                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center gap-3">
                      <div class={[
                        "w-4 h-4 rounded-full",
                        cond do
                          gpio_state.direction == :output && gpio_state.value == 1 ->
                            "bg-green-500 shadow-lg shadow-green-500/50"

                          gpio_state.direction == :output && gpio_state.value == 0 ->
                            "bg-slate-300"

                          gpio_state.direction == :input && gpio_state.value == 1 ->
                            "bg-amber-500 shadow-lg shadow-amber-500/50"

                          gpio_state.direction == :input && gpio_state.value == 0 ->
                            "bg-slate-300"

                          true ->
                            "bg-slate-400"
                        end
                      ]} />
                      <span class="font-bold text-slate-800 text-lg">{display}</span>
                    </div>
                    <button
                      phx-click="close_gpio"
                      phx-value-label={label}
                      class="px-3 py-2 rounded-lg bg-red-100 text-red-700 hover:bg-red-200 font-semibold text-sm transition-all flex items-center gap-2"
                    >
                      <.icon name="hero-x-mark" class="size-4" /> Close
                    </button>
                  </div>

                  <div class="space-y-4">
                    <div class="flex gap-2">
                      <button
                        phx-click="set_direction"
                        phx-value-label={label}
                        phx-value-direction="input"
                        class={[
                          "flex-1 px-4 py-3 rounded-lg font-semibold text-sm transition-all flex items-center justify-center gap-2",
                          if(gpio_state.direction == :input,
                            do: "bg-cyan-500 text-white shadow-md",
                            else: "bg-slate-200 text-slate-700 hover:bg-slate-300"
                          )
                        ]}
                      >
                        <.icon name="hero-arrow-down-tray" class="size-4" /> Input
                      </button>
                      <button
                        phx-click="set_direction"
                        phx-value-label={label}
                        phx-value-direction="output"
                        class={[
                          "flex-1 px-4 py-3 rounded-lg font-semibold text-sm transition-all flex items-center justify-center gap-2",
                          if(gpio_state.direction == :output,
                            do: "bg-purple-500 text-white shadow-md",
                            else: "bg-slate-200 text-slate-700 hover:bg-slate-300"
                          )
                        ]}
                      >
                        <.icon name="hero-arrow-up-tray" class="size-4" /> Output
                      </button>
                    </div>

                    <%= if gpio_state.direction == :input do %>
                      <div class="bg-slate-50 border border-slate-200 rounded-lg p-4">
                        <div class="flex items-center justify-between mb-3">
                          <span class="text-sm font-semibold text-slate-600">Current Value:</span>
                          <span class={[
                            "text-2xl font-bold",
                            if(gpio_state.value == 1, do: "text-amber-600", else: "text-slate-400")
                          ]}>
                            {if gpio_state.value == 1, do: "HIGH", else: "LOW"}
                          </span>
                        </div>

                        <div class="border-t border-slate-200 pt-3">
                          <label class="block text-sm font-semibold text-slate-600 mb-2">
                            Pull Mode:
                          </label>
                          <div class="grid grid-cols-3 gap-2">
                            <button
                              phx-click="set_pull_mode"
                              phx-value-label={label}
                              phx-value-pull_mode="none"
                              class={[
                                "px-3 py-2 rounded text-xs font-semibold transition-all",
                                if(gpio_state.pull_mode == :none,
                                  do: "bg-slate-600 text-white",
                                  else: "bg-slate-200 text-slate-700 hover:bg-slate-300"
                                )
                              ]}
                            >
                              None
                            </button>
                            <button
                              phx-click="set_pull_mode"
                              phx-value-label={label}
                              phx-value-pull_mode="pullup"
                              class={[
                                "px-3 py-2 rounded text-xs font-semibold transition-all",
                                if(gpio_state.pull_mode == :pullup,
                                  do: "bg-blue-600 text-white",
                                  else: "bg-slate-200 text-slate-700 hover:bg-slate-300"
                                )
                              ]}
                            >
                              Pull-Up
                            </button>
                            <button
                              phx-click="set_pull_mode"
                              phx-value-label={label}
                              phx-value-pull_mode="pulldown"
                              class={[
                                "px-3 py-2 rounded text-xs font-semibold transition-all",
                                if(gpio_state.pull_mode == :pulldown,
                                  do: "bg-orange-600 text-white",
                                  else: "bg-slate-200 text-slate-700 hover:bg-slate-300"
                                )
                              ]}
                            >
                              Pull-Down
                            </button>
                          </div>
                        </div>
                      </div>
                    <% end %>

                    <%= if gpio_state.direction == :output do %>
                      <div class="bg-slate-50 border border-slate-200 rounded-lg p-4">
                        <label class="block text-sm font-semibold text-slate-600 mb-3">
                          Output Value:
                        </label>
                        <div class="grid grid-cols-2 gap-3">
                          <button
                            phx-click="set_value"
                            phx-value-label={label}
                            phx-value-gpio_value="0"
                            class={[
                              "px-4 py-3 rounded-lg font-bold text-base transition-all",
                              if(gpio_state.value == 0,
                                do: "bg-slate-600 text-white shadow-lg",
                                else: "bg-slate-200 text-slate-600 hover:bg-slate-300"
                              )
                            ]}
                          >
                            LOW
                          </button>
                          <button
                            phx-click="set_value"
                            phx-value-label={label}
                            phx-value-gpio_value="1"
                            class={[
                              "px-4 py-3 rounded-lg font-bold text-base transition-all",
                              if(gpio_state.value == 1,
                                do: "bg-green-600 text-white shadow-lg",
                                else: "bg-green-200 text-green-700 hover:bg-green-300"
                              )
                            ]}
                          >
                            HIGH
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <div>
          <h2 class="text-lg font-bold text-slate-800 mb-4">
            <.icon name="hero-list-bullet" class="size-5 inline" /> Available GPIOs
          </h2>

          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
            <%= for gpio <- @available_gpios do %>
              <% is_open = Map.has_key?(@open_gpios, gpio.label) %>
              <% display = display_name(gpio.label, gpio.location) %>
              <button
                phx-click={if !is_open && gpio.available, do: "open_gpio", else: nil}
                phx-value-label={gpio.label}
                disabled={!gpio.available || is_open}
                class={[
                  "px-4 py-4 rounded-lg font-semibold text-sm transition-all border-2 relative",
                  cond do
                    is_open ->
                      "bg-blue-100 border-blue-400 text-blue-700 cursor-default"

                    gpio.available ->
                      "bg-white border-slate-300 text-slate-800 hover:border-blue-400 hover:bg-blue-50 active:scale-95"

                    true ->
                      "bg-slate-100 border-slate-200 text-slate-400 cursor-not-allowed opacity-60"
                  end
                ]}
              >
                <div class="flex flex-col items-center gap-2">
                  <%= if is_open do %>
                    <.icon name="hero-check-circle" class="size-5 text-blue-600" />
                  <% else %>
                    <.icon name="hero-cpu-chip" class="size-5" />
                  <% end %>
                  <span class="font-mono text-xs">{display}</span>
                  <%= if !gpio.available do %>
                    <span class="text-xs text-slate-500 mt-1">In use</span>
                  <% end %>
                </div>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    available_gpios = load_available_gpios()

    if connected?(socket) do
      _ = Process.send_after(self(), :poll_inputs, 1000)
      :ok
    end

    {:ok, assign(socket, available_gpios: available_gpios, open_gpios: %{})}
  end

  def handle_event("open_gpio", %{"label" => label}, socket) do
    gpio = Enum.find(socket.assigns.available_gpios, &(&1.label == label))

    with true <- gpio != nil and gpio.available,
         false <- Map.has_key?(socket.assigns.open_gpios, label),
         {:ok, ref} <- GPIO.open(gpio.location, :input) do
      gpio_state = %{
        ref: ref,
        location: gpio.location,
        direction: :input,
        value: GPIO.read(ref),
        pull_mode: :none
      }

      {:noreply,
       assign(socket, open_gpios: Map.put(socket.assigns.open_gpios, label, gpio_state))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("close_gpio", %{"label" => label}, socket) do
    case Map.pop(socket.assigns.open_gpios, label) do
      {gpio_state, open_gpios} when gpio_state != nil ->
        GPIO.close(gpio_state.ref)
        {:noreply, assign(socket, open_gpios: open_gpios)}

      {nil, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("set_direction", %{"label" => label, "direction" => direction_str}, socket) do
    with gpio_state when gpio_state != nil <- Map.get(socket.assigns.open_gpios, label),
         direction <- String.to_atom(direction_str),
         true <- gpio_state.direction != direction do
      GPIO.close(gpio_state.ref)

      opts = build_gpio_opts(:input, gpio_state.pull_mode, direction)

      case GPIO.open(gpio_state.location, direction, opts) do
        {:ok, ref} ->
          value = if direction == :input, do: GPIO.read(ref), else: 0
          if direction == :output, do: GPIO.write(ref, 0)

          updated_state = %{gpio_state | ref: ref, direction: direction, value: value}

          {:noreply,
           assign(socket, open_gpios: Map.put(socket.assigns.open_gpios, label, updated_state))}

        {:error, _} ->
          reopen_gpio_or_remove(socket, label, gpio_state)
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("set_pull_mode", %{"label" => label, "pull_mode" => pull_mode_str}, socket) do
    with gpio_state when gpio_state != nil <- Map.get(socket.assigns.open_gpios, label),
         :input <- gpio_state.direction,
         pull_mode <- String.to_atom(pull_mode_str),
         true <- gpio_state.pull_mode != pull_mode do
      GPIO.close(gpio_state.ref)

      opts = build_gpio_opts(:input, pull_mode, :input)

      case GPIO.open(gpio_state.location, :input, opts) do
        {:ok, ref} ->
          updated_state = %{gpio_state | ref: ref, pull_mode: pull_mode, value: GPIO.read(ref)}

          {:noreply,
           assign(socket, open_gpios: Map.put(socket.assigns.open_gpios, label, updated_state))}

        {:error, _} ->
          reopen_gpio_or_remove(socket, label, gpio_state)
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("set_value", %{"label" => label, "gpio_value" => value_str}, socket) do
    with gpio_state when gpio_state != nil <- Map.get(socket.assigns.open_gpios, label),
         :output <- gpio_state.direction do
      value = String.to_integer(value_str)
      :ok = GPIO.write(gpio_state.ref, value)

      updated_state = %{gpio_state | value: value}

      {:noreply,
       assign(socket, open_gpios: Map.put(socket.assigns.open_gpios, label, updated_state))}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("myelin:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  def handle_info(:poll_inputs, socket) do
    open_gpios =
      Map.new(socket.assigns.open_gpios, fn {label, gpio_state} ->
        if gpio_state.direction == :input do
          {label, %{gpio_state | value: GPIO.read(gpio_state.ref)}}
        else
          {label, gpio_state}
        end
      end)

    Process.send_after(self(), :poll_inputs, 1000)
    {:noreply, assign(socket, open_gpios: open_gpios)}
  end

  def terminate(_reason, socket) do
    if open_gpios = socket.assigns[:open_gpios] do
      Enum.each(open_gpios, fn {_label, gpio_state} -> GPIO.close(gpio_state.ref) end)
    end

    :ok
  end

  @spec display_name(String.t(), any()) :: String.t()
  defp display_name(label, location) when label in ["", "-", nil] do
    inspect(location)
  end

  defp display_name(label, _location), do: label

  @spec build_gpio_opts(:input | :output, atom(), :input | :output) :: keyword()
  defp build_gpio_opts(:input, pull_mode, :input) when pull_mode != :none do
    [pull_mode: pull_mode]
  end

  defp build_gpio_opts(_, _, _), do: []

  @spec reopen_gpio_or_remove(Phoenix.LiveView.Socket.t(), String.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  defp reopen_gpio_or_remove(socket, label, gpio_state) do
    opts = build_gpio_opts(:input, gpio_state.pull_mode, gpio_state.direction)

    case GPIO.open(gpio_state.location, gpio_state.direction, opts) do
      {:ok, ref} ->
        {:noreply,
         assign(socket,
           open_gpios: Map.put(socket.assigns.open_gpios, label, %{gpio_state | ref: ref})
         )}

      {:error, _} ->
        {:noreply, assign(socket, open_gpios: Map.delete(socket.assigns.open_gpios, label))}
    end
  end

  defp load_available_gpios() do
    Enum.map(GPIO.enumerate(), fn %{label: label, location: location} ->
      {consumer, available} =
        case GPIO.status(location) do
          {:ok, status} -> {status.consumer, status.consumer == ""}
          {:error, _} -> {"Unknown", false}
        end

      %{label: label, location: location, consumer: consumer, available: available}
    end)
  end
end
