defmodule MyApp.Web.PageController do
  use MyApp.Web, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_render("Home", %{text: "Hello World"})
  end

  def non_inertia(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render(:non_inertia)
  end

  def shared(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:foo, "bar")
    |> inertia_put_prop(:text, "I should be overriden")
    |> inertia_render("Home", %{text: "Hello World"})
  end

  def lazy(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:lazy_1, fn -> "lazy_1" end)
    |> inertia_put_prop(:nested, %{lazy_2: fn -> "lazy_2" end})
    |> inertia_render("Home", %{lazy_3: &lazy_3/0})
  end

  def nested(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, %{b: %{c: "c", d: "d", e: %{f: "f", g: "g", h: %{}}}})
    |> inertia_render("Home")
  end

  def always(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, "a")
    |> inertia_put_prop(:b, "b")
    |> inertia_put_prop(:important, inertia_always("stuff"))
    |> inertia_render("Home")
  end

  def tagged_lazy(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, inertia_optional(fn -> "a" end))
    |> inertia_put_prop(:b, "b")
    |> inertia_render("Home")
  end

  def changeset_errors(conn, _params) do
    changeset = MyApp.User.changeset(%MyApp.User{}, %{settings: %{}})

    conn
    |> assign(:page_title, "Home")
    |> inertia_put_errors(changeset)
    |> inertia_render("Home")
  end

  def redirect_on_error(conn, _params) do
    changeset = MyApp.User.changeset(%MyApp.User{}, %{settings: %{}})

    conn
    |> inertia_put_errors(changeset)
    |> redirect(to: ~p"/")
  end

  def bad_error_map(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_errors(%{user: %{name: ["is required"]}})
    |> inertia_render("Home")
  end

  def external_redirect(conn, _params) do
    redirect(conn, external: "http://www.example.com/")
  end

  def overridden_flash(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:flash, %{foo: "bar"})
    |> inertia_render("Home")
  end

  def struct_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:now, ~U[2024-07-04 00:00:00Z])
    |> inertia_render("Home")
  end

  def binary_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:content, "’")
    |> inertia_render("Home")
  end

  def merge_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, inertia_merge("a"))
    |> inertia_put_prop(:b, inertia_merge("b"))
    |> inertia_put_prop(:c, "c")
    |> inertia_render("Home")
  end

  def deep_merge_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, inertia_deep_merge(%{a: %{b: %{c: 1}}}))
    |> inertia_put_prop(:b, inertia_deep_merge([:a, :b]))
    |> inertia_put_prop(:c, inertia_merge("c"))
    |> inertia_put_prop(:d, "d")
    |> inertia_render("Home")
  end

  def deferred_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:a, inertia_defer(fn -> "a" end))
    |> inertia_put_prop(:b, inertia_defer(fn -> "b" end, "dashboard"))
    |> inertia_put_prop(:c, inertia_defer(fn -> "c" end) |> inertia_merge())
    |> inertia_put_prop(:d, "d")
    |> inertia_render("Home")
  end

  def encrypted_history(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_encrypt_history()
    |> inertia_render("Home")
  end

  def cleared_history(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_clear_history()
    |> inertia_render("Home")
  end

  def camelized_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:first_name, "Bob")
    |> inertia_put_prop(:items, [%{item_name: "Foo"}])
    |> inertia_camelize_props()
    |> inertia_render("Home")
  end

  def camelized_deferred_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(:first_name, "Bob")
    |> inertia_put_prop(:items, inertia_defer(fn -> [%{item_name: "Foo"}] end))
    |> inertia_camelize_props()
    |> inertia_render("Home")
  end

  def preserved_case_props(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_put_prop(preserve_case(:first_name), "Bob")
    |> inertia_put_prop(:last_name, "Jones")
    |> inertia_put_prop(:profile, %{preserve_case(:birth_year) => "Foo"})
    |> inertia_camelize_props()
    |> inertia_render("Home")
  end

  def force_redirect(conn, _params) do
    conn
    |> inertia_force_redirect()
    |> redirect(to: "/")
  end

  def local_ssr(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> inertia_render("Home", ssr: true)
  end

  def update(conn, _params) do
    conn
    |> put_flash(:info, "Updated")
    |> redirect(to: "/")
  end

  def patch(conn, _params) do
    conn
    |> put_flash(:info, "Patched")
    |> redirect(to: "/")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Deleted")
    |> redirect(to: "/")
  end

  defp lazy_3 do
    "lazy_3"
  end
end
