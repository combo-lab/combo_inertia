import Config

config :combo_inertia, MyApp.Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/O3KVxcR9F1pdBacw1BiK4RQUs6lE6fEeCoND85ebDK6+x8VoKgbojn7lMkRF1ft",
  server: false

config :logger, level: :warning
