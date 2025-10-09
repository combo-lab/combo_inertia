defmodule MyApp.Web.Endpoint do
  use Combo.Endpoint, otp_app: :combo_inertia

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: "kqNMFR+7",
    same_site: "Lax"
  ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :combo_inertia,
    gzip: false,
    only: MyApp.Web.static_paths()

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:combo, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Combo.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MyApp.Web.Router
end
