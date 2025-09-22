defmodule MyApp.Web do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MyApp.Web, :controller
      use MyApp.Web, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Combo.Router

      import Plug.Conn
      import Combo.Conn
    end
  end

  def controller do
    quote do
      use Combo.Controller, formats: [:html, :json]

      import Plug.Conn
      import Combo.Conn
      import Combo.Inertia.Conn

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      import Combo.Conn,
        only: [
          get_csrf_token: 0,
          view_module!: 1,
          view_template!: 1
        ]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Combo.HTML

      import Combo.Inertia.HTML

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Combo.VerifiedRoutes,
        endpoint: MyApp.Web.Endpoint,
        router: MyApp.Web.Router,
        statics: MyApp.Web.static_paths()
    end
  end
end
