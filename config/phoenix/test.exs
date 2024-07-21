import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kiosk_example, KioskExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KDWBC8aVVr1IAe0UrtLkujZs2LNHZupBGAHNNkJc/Uk9exEmtN0wGtML4nZAVndA",
  server: false

# In test we don't send emails
config :kiosk_example, KioskExample.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
