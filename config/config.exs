# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1721520436"

config :mix_tasks_upload_hotswap,
  app_name: :kiosk_example,
  nodes: [:"kiosk_example@nerves.local"],
  cookie: :nerves_is_awesome

import_config "phoenix/config.exs"

if Mix.target() == :host do
  import_config "host.exs"
else
  config :kiosk_example, KioskExampleWeb.Endpoint, server: true

  import_config "target.exs"
end
