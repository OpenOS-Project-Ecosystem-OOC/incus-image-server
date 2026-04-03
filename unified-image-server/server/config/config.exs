# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :polar,
  ecto_repos: [Polar.Repo],
  generators: [timestamp_type: :utc_datetime]

config :polar, Polar.Vault, json_library: Jason

config :polar, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 3],
  repo: Polar.Repo,
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"@daily", Polar.Streams.Version.Pruning}]}
  ]

# Configures the endpoint
config :polar, PolarWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PolarWeb.ErrorHTML, json: PolarWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Polar.PubSub,
  live_view: [signing_salt: "8KteqLCk"]

config :polar, Polar.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :polar, Polar.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  polar: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  polar: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ── Storage backend ───────────────────────────────────────────────────────────
# Default: S3-compatible. Override in runtime.exs with env vars.
# To use local filesystem storage, set storage_adapter to Polar.Storage.Local.
#
# S3 (AWS, MinIO, Cloudflare R2, Backblaze B2):
#   config :polar, :storage_adapter, Polar.Storage.S3
#   config :polar, Polar.Storage.S3,
#     access_key_id:     System.get_env("STORAGE_ACCESS_KEY_ID"),
#     secret_access_key: System.get_env("STORAGE_SECRET_ACCESS_KEY"),
#     region:            System.get_env("STORAGE_REGION", "us-east-1"),
#     bucket:            System.get_env("STORAGE_BUCKET"),
#     endpoint:          System.get_env("STORAGE_ENDPOINT")
#
# Local filesystem:
#   config :polar, :storage_adapter, Polar.Storage.Local
#   config :polar, Polar.Storage.Local,
#     base_path: System.get_env("STORAGE_BASE_PATH", "/var/lib/polar/storage"),
#     base_url:  System.get_env("STORAGE_BASE_URL")
config :polar, :storage_adapter, Polar.Storage.S3

# Increase upload body limit to 4 GB for large rootfs files.
# Plug's default is 8 MB which is far too small for container images.
config :polar, :upload_max_file_size, 4 * 1024 * 1024 * 1024

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
