import Config

config :combo_inertia, MyApp.Web.Endpoint,
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
