defmodule KioskDemoWeb.HomeLive do
  use KioskDemoWeb, :live_view
  use KioskDemoWeb.Live.Screensaver

  import KioskDemoWeb.Components.MetricChart

  @metrics_refresh_ms 1_000
  @cpu_chart_id "cpu-chart"
  @cpu_chart_height 120
  # Number of samples kept in the rolling in-memory window for the chart.
  @metrics_window_points 120

  def mount(_params, _session, socket) do
    {:ok, name} = :inet.gethostname()

    system_info = %{
      serial_number: get_serial_number(),
      firmware: get_firmware_info(),
      ip_addresses: get_ip_addresses()
    }

    if connected?(socket) do
      _ = Process.send_after(self(), :refresh_ip_addresses, 10_000)
      _ = Process.send_after(self(), :refresh_metrics, @metrics_refresh_ms)
      :ok
    end

    metrics = initial_metrics()

    socket =
      socket
      |> assign(:hostname, to_string(name))
      |> assign(:system_info, system_info)
      |> assign(:metrics, metrics)
      |> assign(:system_info_expanded, true)
      |> assign(:cpu_chart_id, @cpu_chart_id)
      |> assign(:cpu_chart_height, @cpu_chart_height)
      |> init_screensaver()
      |> push_cpu_chart(metrics)

    {:ok, socket}
  end

  def handle_event("font_diag", info, socket) do
    require Logger
    Logger.info("[FontDiag] #{inspect(info)}")
    {:noreply, socket}
  end

  def handle_event("toggle_system_info", _params, socket) do
    socket =
      socket
      |> assign(:system_info_expanded, not socket.assigns.system_info_expanded)

    {:noreply, KioskDemoWeb.Live.Screensaver.handle_user_activity(socket)}
  end

  defp get_serial_number do
    if Code.ensure_loaded?(Nerves.Runtime) do
      Nerves.Runtime.serial_number()
    else
      "unconfigured"
    end
  end

  defp get_firmware_info do
    if Code.ensure_loaded?(Nerves.Runtime.KV) do
      kv = Nerves.Runtime.KV.get_all_active()

      %{
        architecture: Map.get(kv, "nerves_fw_architecture", "N/A"),
        description: Map.get(kv, "nerves_fw_description", "N/A"),
        platform: Map.get(kv, "nerves_fw_platform", "N/A"),
        version: Map.get(kv, "nerves_fw_version", "N/A")
      }
    else
      %{
        architecture: "generic",
        description: "N/A",
        platform: "host",
        version: "0.0.0"
      }
    end
  end

  # It's easier to use VintageNet, but this is available on host
  defp get_ip_addresses() do
    {:ok, interfaces} = :inet.getifaddrs()

    interfaces
    |> Enum.filter(&good_ifname/1)
    |> Enum.flat_map(fn
      {name, opts} ->
        ifname = to_string(name)
        Enum.flat_map(opts, &extract_address(ifname, &1))
    end)
  end

  defp good_ifname({~c"lo" ++ _, _opts}), do: false
  defp good_ifname({~c"utun" ++ _, _opts}), do: false
  defp good_ifname({~c"veth" ++ _, _opts}), do: false
  defp good_ifname({~c"br" ++ _, _opts}), do: false
  defp good_ifname(_anything_else), do: true

  defp extract_address(ifname, {:addr, addr}),
    do: [%{interface: ifname, address: :inet.ntoa(addr) |> to_string()}]

  defp extract_address(_ifname, _), do: []

  def handle_info(:refresh_ip_addresses, socket) do
    updated_system_info = Map.put(socket.assigns.system_info, :ip_addresses, get_ip_addresses())
    Process.send_after(self(), :refresh_ip_addresses, 10_000)
    {:noreply, assign(socket, :system_info, updated_system_info)}
  end

  def handle_info(:refresh_metrics, socket) do
    Process.send_after(self(), :refresh_metrics, @metrics_refresh_ms)
    metrics = push_sample(socket.assigns.metrics, KioskDemo.SystemMetrics.sample())
    {:noreply, socket |> assign(:metrics, metrics) |> push_cpu_chart(metrics)}
  end

  defp push_cpu_chart(socket, metrics) do
    if socket.assigns.screensaver_active do
      # Skip the push while the screensaver covers the chart. The hook's
      # rAF loop winds down within ~1s once it stops getting fresh targets,
      # so CPU drops to zero shortly after activation.
      socket
    else
      layers =
        KioskDemoWeb.Components.MetricChart.build_layers(%{
          series: metrics.cpu,
          overlays: [
            %{series: metrics.memory, fill: "#334155", height_scale: 0.95},
            %{series: metrics.load_avg, fill: "#475569", height_scale: 0.65}
          ],
          height: @cpu_chart_height,
          light_color: "#f8fafc",
          min: 0,
          max: 100,
          height_scale: 0.35
        })

      push_event(socket, "chart:" <> @cpu_chart_id, %{layers: layers})
    end
  end

  # Metrics are sampled live and kept only in this process's memory — no
  # persistence. Each tick appends the current reading and drops the oldest
  # once the window is full.
  #
  # Seed every series with a full window of the first reading. The canvas
  # chart's smooth scroll assumes a constant point count (its step is
  # `width / point_count`); a buffer that grows from empty re-spaces the whole
  # line on every push, which reads as horizontal twitching until it fills.
  defp initial_metrics() do
    %{cpu_util: cpu, memory_used_bytes: memory, load_avg_1: load_avg} =
      KioskDemo.SystemMetrics.sample()

    %{
      cpu: full_window(cpu),
      memory: full_window(memory),
      load_avg: full_window(load_avg)
    }
  end

  defp full_window(value), do: List.duplicate(%{value: value}, @metrics_window_points)

  defp push_sample(metrics, %{cpu_util: cpu, memory_used_bytes: memory, load_avg_1: load_avg}) do
    %{
      cpu: append_point(metrics.cpu, cpu),
      memory: append_point(metrics.memory, memory),
      load_avg: append_point(metrics.load_avg, load_avg)
    }
  end

  defp append_point(series, value) do
    (series ++ [%{value: value}]) |> Enum.take(-@metrics_window_points)
  end

  def render(assigns) do
    ~H"""
    <style>
      .icon-container {
        background-color: #42A7C6;
        border-radius: 10px;
        padding: 6px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        flex: 0 0 auto;
      }

      .kiosk-hero-dark {
        position: relative;
        background-color: #000;
        overflow: hidden;
        isolation: isolate;
      }

      .kiosk-hero-dark > * {
        position: relative;
        z-index: 1;
      }

      .kiosk-body-light {
        position: relative;
        background-color: #f8fafc;
        overflow: hidden;
        isolation: isolate;
      }

      .kiosk-body-light::before {
        content: "";
        position: absolute;
        inset: -20%;
        z-index: -1;
        pointer-events: none;
        background-image:
          radial-gradient(ellipse 35% 35% at 85% 75%, oklch(75% 0.14 245 / 0.45), transparent 70%),
          radial-gradient(ellipse 30% 28% at 70% 80%, oklch(78% 0.12 225 / 0.38), transparent 65%),
          radial-gradient(ellipse 28% 32% at 90% 55%, oklch(83% 0.10 210 / 0.30), transparent 60%),
          radial-gradient(ellipse 25% 22% at 15% 30%, oklch(80% 0.09 290 / 0.30), transparent 60%),
          radial-gradient(ellipse 25% 22% at 60% 70%, oklch(80% 0.09 255 / 0.25), transparent 60%);
      }

      .block-row {
        display: grid;
        grid-template-columns: auto 1fr auto;
        align-items: center;
        gap: 1rem;
        padding: 0.75rem 0.25rem;
      }

      .block-row.top {
        align-items: start;
      }

      .block-body {
        grid-column: 1 / -1;
      }

      .nerves-blue {
        color: #33647E;
      }

      .btn-cta {
        min-width: 13rem;
        justify-content: center;
      }

      .kiosk-title {
        font-family: "Poppins", "Helvetica Neue", "Segoe UI", system-ui, -apple-system, sans-serif;
        font-weight: 100;
        font-size: clamp(2.75rem, 5.5vw, 4.75rem);
        line-height: 1.1;
        letter-spacing: 0;
      }
    </style>

    <div
      {screensaver_events()}
      class="relative min-h-screen flex flex-col"
    >
      <div id="fps-counter" class="fps-counter" phx-hook=".FpsCounter" phx-update="ignore">--</div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".FpsCounter">
        export default {
          mounted() {
            let last = performance.now();
            let frames = 0;
            const el = this.el;
            const tick = (now) => {
              frames++;
              const elapsed = now - last;
              if (elapsed >= 500) {
                const fps = frames * 1000 / elapsed;
                el.textContent = fps.toFixed(0);
                el.dataset.warn = fps < 30 ? "bad" : (fps < 55 ? "true" : "false");
                frames = 0;
                last = now;
              }
              this._raf = requestAnimationFrame(tick);
            };
            this._raf = requestAnimationFrame(tick);

            // Detailed font diagnostic: try to actively load each face and report
            // the resulting status / error from the FontFace objects, plus a
            // direct fetch() to confirm the woff2 URL is reachable from this
            // browsing context.
            if (document.fonts) {
              const specs = ["100 16px Poppins", "400 16px Poppins", "400 16px Nunito"];
              const results = {};
              Promise.all(specs.map(s =>
                document.fonts.load(s).then(faces => {
                  results[s] = {count: faces.length, status: faces.map(f => f.status)};
                }).catch(e => { results[s] = {error: String(e), name: e.name}; })
              )).then(async () => {
                // Direct fetch test for the woff2 files
                const urls = ["/fonts/Poppins-100.woff2", "/fonts/Nunito-Variable.woff2"];
                const fetches = {};
                for (const u of urls) {
                  try {
                    const r = await fetch(u);
                    const buf = await r.arrayBuffer();
                    fetches[u] = {status: r.status, bytes: buf.byteLength, ct: r.headers.get("content-type")};
                  } catch (e) {
                    fetches[u] = {error: String(e)};
                  }
                }
                this.pushEvent("font_diag", {
                  loads: results,
                  fetches,
                  size: document.fonts.size,
                  ua: navigator.userAgent
                });
              });
            }
          },
          destroyed() {
            if (this._raf) cancelAnimationFrame(this._raf);
          }
        }
      </script>
      <.screensaver_overlay active={@screensaver_active} />

      <section class="kiosk-hero-dark">
        <div class="px-4 pt-16 pb-20 sm:px-6 sm:pt-20 sm:pb-24 lg:px-8 xl:px-28 xl:pt-24 xl:pb-32">
          <div class="mx-auto max-w-6xl text-center">
            <h1 class="kiosk-title text-slate-100">
              Nerves Web Kiosk
            </h1>
          </div>
        </div>
        <div role="separator" aria-label="Live CPU usage" class="block leading-none">
          <.line_chart
            id={@cpu_chart_id}
            dark_color="#000000"
            height={@cpu_chart_height}
            update_interval_ms={1_000}
          />
        </div>
      </section>

      <div class="kiosk-body-light flex-1 px-4 py-6 sm:px-6 sm:py-8 lg:px-8 xl:px-28 xl:py-10">
        <div class="mx-auto max-w-6xl space-y-3">
          <div class="block-row">
            <div class="icon-container">
              <.icon name="hero-chart-bar" class="size-6 text-white" />
            </div>
            <p class="text-xl font-bold text-slate-800">Phoenix LiveDashboard</p>
            <a href="/dashboard" class="btn btn-primary btn-cta">
              Open Dashboard <.icon name="hero-arrow-right" class="size-4" />
            </a>
          </div>

          <div class="block-row">
            <div class="icon-container">
              <.icon name="hero-bolt" class="size-6 text-white" />
            </div>
            <p class="text-xl font-bold text-slate-800">GPIO Control</p>
            <a href="/gpio" class="btn btn-primary btn-cta">
              Open GPIO Control <.icon name="hero-arrow-right" class="size-4" />
            </a>
          </div>

          <div class="block-row">
            <div class="icon-container">
              <.icon name="hero-computer-desktop" class="size-6 text-white" />
            </div>
            <p class="text-xl font-bold text-slate-800">SSH Access</p>
            <span class="text-sm text-slate-600">
              password:
              <span class="font-bold text-slate-800 bg-yellow-100 px-2 py-1 rounded">kiosk</span>
            </span>
            <pre class="block-body bg-slate-900 text-green-400 px-4 py-3 rounded-lg text-sm font-mono"><code>ssh kiosk@{(@hostname || "nerves-xxxx")}.local</code></pre>
          </div>

          <div class="block-row">
            <div class="icon-container">
              <.icon name="hero-cpu-chip" class="size-6 text-white" />
            </div>
            <p class="text-xl font-bold text-slate-800">System Information</p>
            <button
              type="button"
              phx-click="toggle_system_info"
              class="btn btn-ghost btn-cta"
              aria-expanded={to_string(@system_info_expanded)}
            >
              <%= if @system_info_expanded do %>
                Hide <.icon name="hero-chevron-up" class="size-4" />
              <% else %>
                Show <.icon name="hero-chevron-down" class="size-4" />
              <% end %>
            </button>
            <div :if={@system_info_expanded} class="block-body">
              <table class="w-full text-sm">
                <tbody class="divide-y divide-slate-200">
                  <tr>
                    <td class="py-2 pr-4 font-semibold text-slate-700">Serial Number</td>
                    <td class="py-2 text-slate-900 break-all font-mono text-xs">
                      {@system_info.serial_number}
                    </td>
                  </tr>
                  <tr>
                    <td class="py-2 pr-4 font-semibold text-slate-700">Architecture</td>
                    <td class="py-2 text-slate-900">{@system_info.firmware.architecture}</td>
                  </tr>
                  <tr>
                    <td class="py-2 pr-4 font-semibold text-slate-700">Platform</td>
                    <td class="py-2 text-slate-900">{@system_info.firmware.platform}</td>
                  </tr>
                  <tr>
                    <td class="py-2 pr-4 font-semibold text-slate-700">Version</td>
                    <td class="py-2 text-slate-900">{@system_info.firmware.version}</td>
                  </tr>
                  <tr>
                    <td class="py-2 pr-4 font-semibold text-slate-700">Description</td>
                    <td class="py-2 text-slate-900">{@system_info.firmware.description}</td>
                  </tr>
                  <%= if length(@system_info.ip_addresses) > 0 do %>
                    <tr>
                      <td class="py-2 pr-4 font-semibold text-slate-700 align-top">IP Addresses</td>
                      <td class="py-2 text-slate-900">
                        <div class="space-y-1">
                          <%= for ip <- @system_info.ip_addresses do %>
                            <div class="flex items-center gap-2">
                              <span class="font-mono text-xs bg-slate-100 px-2 py-1 rounded">
                                {ip.address}
                              </span>
                              <span class="text-xs text-slate-500">({ip.interface})</span>
                            </div>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <div class="block-row top">
            <div class="icon-container">
              <.icon name="hero-information-circle" class="size-6 text-white" />
            </div>
            <div class="min-w-0 flex flex-col gap-2">
              <p class="text-xl font-bold text-slate-800 leading-tight">Learn More</p>
              <a
                href="https://github.com/nerves-web-kiosk/kiosk_demo"
                target="_blank"
                class="inline-flex items-center gap-1 text-blue-600 hover:text-blue-700 text-sm font-medium truncate"
              >
                <.icon name="hero-arrow-top-right-on-square" class="size-4" />
                github.com/nerves-web-kiosk/kiosk_demo
              </a>
            </div>
            <img
              alt="QR code for source repository"
              src={~p"/images/qr_source.png"}
              width="160"
              height="160"
              class="rounded-lg block"
            />
          </div>

          <p class="text-center text-sm text-slate-500 pt-4">
            Built with ❤️ using <span class="font-semibold text-purple-600">Elixir</span>, <span class="font-semibold text-orange-600">Phoenix</span>, and
            <span class="font-semibold nerves-blue">Nerves</span>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
