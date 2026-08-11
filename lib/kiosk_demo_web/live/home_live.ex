defmodule KioskDemoWeb.HomeLive do
  use KioskDemoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, name} = :inet.gethostname()

    system_info = %{
      serial_number: get_serial_number(),
      firmware: get_firmware_info(),
      ip_addresses: get_ip_addresses()
    }

    if connected?(socket) do
      _ = Process.send_after(self(), :refresh_ip_addresses, 10_000)
      :ok
    end

    socket =
      socket
      |> assign(:hostname, to_string(name))
      |> assign(:system_info, system_info)

    {:ok, socket}
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

  def handle_event("myelin:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  def handle_info(:refresh_ip_addresses, socket) do
    updated_system_info = Map.put(socket.assigns.system_info, :ip_addresses, get_ip_addresses())
    Process.send_after(self(), :refresh_ip_addresses, 10_000)
    {:noreply, assign(socket, :system_info, updated_system_info)}
  end

  def render(assigns) do
    ~H"""
    <style>
      .card-hover {
        transition: transform 0.2s ease-out;
      }

      .card-hover:hover {
        transform: translateY(-2px);
      }

      .icon-container {
        border-radius: 12px;
        padding: 8px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
      }

      .icon-container.dashboard {
        background-color: #f5576c;
      }

      .icon-container.gpio {
        background-color: #00d4ff;
      }

      .icon-container.ssh {
        background-color: #38f9d7;
      }

      .icon-container.system {
        background-color: #ff9a56;
      }

      .icon-container.info {
        background-color: #66d9ef;
      }
    </style>

    <div class="relative min-h-screen bg-slate-50">
      <div class="px-4 py-10 sm:px-6 sm:py-12 lg:px-8 xl:px-28 xl:py-16">
        <div class="mx-auto max-w-6xl">
          <div class="text-center mb-16">
            <div class="inline-block bg-gradient-to-r from-indigo-600 to-purple-600 rounded-3xl px-8 py-12 mb-6 shadow-lg">
              <h1 class="text-5xl font-bold text-white mb-3 tracking-tight">
                Nerves Web Kiosk
              </h1>
              <p class="text-white/90 text-lg font-medium">
                Powered by Phoenix LiveView & Nerves
              </p>
            </div>

            <p class="mt-6 text-xl text-slate-700 max-w-2xl mx-auto leading-relaxed">
              A full-screen web browser experience with real-time capabilities,
              running on embedded hardware
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div class="card-hover rounded-2xl bg-white shadow-md p-6 border border-slate-200">
              <div class="flex items-center gap-3 mb-4">
                <div class="icon-container dashboard">
                  <.icon name="hero-chart-bar" class="size-6 text-white" />
                </div>
                <p class="text-xl font-bold text-slate-800">Phoenix LiveDashboard</p>
              </div>
              <p class="mt-3 text-slate-600 leading-relaxed">
                View real-time metrics, introspect processes, and monitor your application's
                performance with interactive visualizations.
              </p>
              <a
                href="/dashboard"
                class="btn btn-primary mt-4 w-full"
              >
                <.icon name="hero-arrow-right" class="size-5" /> Open Dashboard
              </a>
            </div>

            <div class="card-hover rounded-2xl bg-white shadow-md p-6 border border-slate-200">
              <div class="flex items-center gap-3 mb-4">
                <div class="icon-container gpio">
                  <.icon name="hero-bolt" class="size-6 text-white" />
                </div>
                <p class="text-xl font-bold text-slate-800">GPIO Control</p>
              </div>
              <p class="mt-3 text-slate-600 leading-relaxed">
                Interact with hardware GPIO pins directly from your browser. Control outputs
                and monitor inputs in real-time.
              </p>
              <a
                href="/gpio"
                class="btn btn-primary mt-4 w-full"
              >
                <.icon name="hero-arrow-right" class="size-5" /> Open GPIO Control
              </a>
            </div>

            <div class="card-hover rounded-2xl bg-white shadow-md p-6 border border-slate-200">
              <div class="flex items-center gap-3 mb-4">
                <div class="icon-container ssh">
                  <.icon name="hero-computer-desktop" class="size-6 text-white" />
                </div>
                <p class="text-xl font-bold text-slate-800">SSH Access</p>
              </div>
              <p class="mt-3 text-slate-600 mb-4 leading-relaxed">
                Connect via SSH to access an IEx shell for debugging and system management:
              </p>
              <pre class="bg-slate-900 text-green-400 p-4 rounded-lg text-sm font-mono"><code>ssh kiosk@{(@hostname || "nerves-xxxx")}.local</code></pre>
              <div class="mt-4 bg-slate-50 p-3 rounded-lg border border-slate-200">
                <p class="text-sm text-slate-600">
                  Default password:
                  <span class="font-bold text-slate-800 bg-yellow-100 px-2 py-1 rounded">kiosk</span>
                </p>
              </div>
            </div>

            <div class="card-hover rounded-2xl bg-white shadow-md p-6 border border-slate-200">
              <div class="flex items-center gap-3 mb-4">
                <div class="icon-container system">
                  <.icon name="hero-cpu-chip" class="size-6 text-white" />
                </div>
                <p class="text-xl font-bold text-slate-800">System Information</p>
              </div>
              <div class="mt-4">
                <table class="w-full text-sm">
                  <tbody class="divide-y divide-slate-200">
                    <tr class="hover:bg-slate-50">
                      <td class="py-3 pr-4 font-semibold text-slate-700">Serial Number</td>
                      <td class="py-3 text-slate-900 break-all font-mono text-xs">
                        {@system_info.serial_number}
                      </td>
                    </tr>
                    <tr class="hover:bg-slate-50">
                      <td class="py-3 pr-4 font-semibold text-slate-700">Architecture</td>
                      <td class="py-3 text-slate-900">
                        {@system_info.firmware.architecture}
                      </td>
                    </tr>
                    <tr class="hover:bg-slate-50">
                      <td class="py-3 pr-4 font-semibold text-slate-700">Platform</td>
                      <td class="py-3 text-slate-900">{@system_info.firmware.platform}</td>
                    </tr>
                    <tr class="hover:bg-slate-50">
                      <td class="py-3 pr-4 font-semibold text-slate-700">Version</td>
                      <td class="py-3 text-slate-900">{@system_info.firmware.version}</td>
                    </tr>
                    <tr class="hover:bg-slate-50">
                      <td class="py-3 pr-4 font-semibold text-slate-700">Description</td>
                      <td class="py-3 text-slate-900">
                        {@system_info.firmware.description}
                      </td>
                    </tr>
                    <%= if length(@system_info.ip_addresses) > 0 do %>
                      <tr class="hover:bg-slate-50">
                        <td class="py-3 pr-4 font-semibold text-slate-700 align-top">IP Addresses</td>
                        <td class="py-3 text-slate-900">
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

            <div class="card-hover rounded-2xl bg-white shadow-md p-6 border border-slate-200 md:col-span-2">
              <div class="flex flex-col md:flex-row items-start md:items-center gap-6">
                <div class="flex-1">
                  <div class="flex items-center gap-3 mb-4">
                    <div class="icon-container info">
                      <.icon name="hero-information-circle" class="size-6 text-white" />
                    </div>
                    <p class="text-xl font-bold text-slate-800">Learn More</p>
                  </div>
                  <p class="mt-3 text-slate-600 leading-relaxed mb-4">
                    Source code, documentation, and community support are available on GitHub.
                    Scan the QR code or visit the repository to get started:
                  </p>
                  <a
                    href="https://github.com/nerves-web-kiosk/kiosk_demo"
                    target="_blank"
                    class="inline-flex items-center gap-2 text-blue-600 hover:text-blue-700 font-medium"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="size-5" />
                    github.com/nerves-web-kiosk/kiosk_demo
                  </a>
                </div>
                <div class="flex justify-center md:justify-end">
                  <div class="bg-slate-50 p-4 rounded-xl border-2 border-slate-200">
                    <img
                      alt="QR code for source repository"
                      src={~p"/images/qr_source.png"}
                      width="160"
                      height="160"
                      class="rounded"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-12 text-center">
            <p class="text-sm text-slate-500">
              Built with ❤️ using <span class="font-semibold text-purple-600">Elixir</span>, <span class="font-semibold text-orange-600">Phoenix</span>, and
              <span class="font-semibold text-green-600">Nerves</span>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
