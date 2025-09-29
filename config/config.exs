import Config

config :combo_inertia, MyApp.Web.Endpoint,
  url: [host: "localhost"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  render_errors: [
    formats: [html: MyApp.Web.ErrorHTML, json: MyApp.Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyApp.PubSub,
  inertia: [
    assets_version: :auto,
    camelize_props: false
  ]

if Mix.env() == :test do
  import_config "test.exs"
end
