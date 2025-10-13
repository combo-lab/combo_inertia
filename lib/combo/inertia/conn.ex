defmodule Combo.Inertia.Conn do
  @moduledoc """
  `%Plug.Conn{}` helpers for rendering Inertia responses.
  """

  require Logger

  import Plug.Conn
  import Combo.Conn

  alias Combo.Inertia.Errors
  alias Combo.Inertia.SSR.RenderError
  alias Combo.Inertia.SSR
  alias Combo.Inertia.Config

  @title_regex ~r/<title inertia>(.*?)<\/title>/

  @type component :: String.t()

  @type raw_prop_key :: atom() | String.t()
  @type prop_key :: raw_prop_key() | preserved_prop_key()
  @type prop_value :: any()
  @type props :: map()

  @type render_opt :: {:ssr, boolean()}
  @type render_opts :: [render_opt()]

  @opaque optional :: {:optional, fun()}
  @opaque always :: {:always, any()}
  @opaque merge :: {:merge, any()}
  @opaque deep_merge :: {:deep_merge, any()}
  @opaque defer :: {:defer, {fun(), String.t()}}
  @opaque preserved_prop_key :: {:preserve, raw_prop_key()}

  @doc """
  Puts a prop to the Inertia page data.

  ## Examples

      # ALWAYS included on standard visits
      # OPTIONALLY included on partial reloads
      # ALWAYS evaluated
      inertia_put_prop(conn, :users, Users.all())

      # ALWAYS included on standard visits
      # OPTIONALLY included on partial reloads
      # ONLY evaluated when needed
      inertia_put_prop(conn, :users, fn -> Users.all() end)

  """
  @spec inertia_put_prop(Plug.Conn.t(), prop_key(), prop_value()) :: Plug.Conn.t()
  def inertia_put_prop(conn, key, value) do
    shared = conn.private[:inertia_shared] || %{}
    new_shared = Map.put(shared, key, value)
    put_private(conn, :inertia_shared, new_shared)
  end

  ## Partial reloads

  @doc """
  Marks a prop as "optional", which means it will only get evaluated when
  explicitly requested in a partial reload.

  ## Examples

      // NEVER included on standard visits
      // OPTIONALLY included on partial reloads
      // ONLY evaluated when needed
      inertia_put_prop(conn, :users, inertia_optional(fn -> Users.all() end))

  """
  @spec inertia_optional(fun()) :: optional()
  def inertia_optional(fun) when is_function(fun, 0), do: {:optional, fun}

  @doc """
  Marks a prop as "always", which means it will be always included in the props.

  ## Examples

      # ALWAYS included on standard visits
      # ALWAYS included on partial reloads
      # ALWAYS evaluated
      inertia_put_prop(conn, :users, inertia_always(Users.all()))

  """
  @spec inertia_always(value :: any()) :: always()
  def inertia_always(value), do: {:always, value}

  ## Deffered props

  @doc """
  Marks a prop as "defer", which means it will be loaded after initial page
  render.

  ## Examples

      inertia_put_prop(conn, :users, inertia_defer(fn -> Users.all() end))
      inertia_put_prop(conn, :users, inertia_defer(fn -> Users.all() end, "group1"))

  """
  @spec inertia_defer(fun()) :: defer()
  def inertia_defer(fun) when is_function(fun, 0), do: inertia_defer(fun, "default")

  @spec inertia_defer(fun(), String.t()) :: defer()
  def inertia_defer(fun, group) when is_function(fun, 0) and is_binary(group) do
    {:defer, {fun, group}}
  end

  ## Merging props

  @doc """
  Marks a prop as "merge", which means it will be merged with existing data on
  the client-side.
  """
  @spec inertia_merge(prop_value()) :: merge()
  def inertia_merge(value), do: {:merge, value}

  @doc """
  Marks a prop as "deep_merge", which means it will be deeply merged with
  existing data on the client-side.
  """
  @spec inertia_deep_merge(prop_value()) :: deep_merge()
  def inertia_deep_merge(value), do: {:deep_merge, value}

  ## Handling prop_key cases

  @doc """
  Prevents auto-transformation of a prop key to camel-case (when
  `camelize_props` is enabled).

  ## Example

      conn
      |> inertia_put_prop(preserve_case(:this_will_not_be_camelized), "value")
      |> inertia_put_prop(:this_will_be_camelized, "another_value")
      |> inertia_camelize_props()
      |> inertia_render("Home")

  You can also use this helper inside of nested props:

      conn
      |> inertia_put_prop(:user, %{
        preserve_case(:this_will_not_be_camelized) => "value",
        this_will_be_camelized: "another_value"
      })
      |> inertia_camelize_props()
      |> inertia_render("Home")
  """
  @spec preserve_case(raw_prop_key()) :: preserved_prop_key()
  def preserve_case(key), do: {:preserve, key}

  @doc """
  Enable (or disable) automatic conversion of prop keys from snake case (e.g.
  `inserted_at`), which is conventional in Elixir, to camel case (e.g.
  `insertedAt`), which is conventional in JavaScript.

  ## Examples

  Using `camelize_props` here will convert `first_name` to `firstName` in the
  response props.

      conn
      |> inertia_put_prop(:first_name, "Bob")
      |> inertia_camelize_props()
      |> inertia_render("Home")

  You may also pass a boolean to the `camelize_props` function (to override any
  previously-set or globally-configured value):

      conn
      |> inertia_put_prop(:first_name, "Bob")
      |> inertia_camelize_props(false)
      |> inertia_render("Home")
  """
  @spec inertia_camelize_props(Plug.Conn.t()) :: Plug.Conn.t()
  def inertia_camelize_props(conn) do
    put_private(conn, :inertia_camelize_props, true)
  end

  @spec inertia_camelize_props(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def inertia_camelize_props(conn, value) when is_boolean(value) do
    put_private(conn, :inertia_camelize_props, value)
  end

  ## History encryption

  @doc """
  Instucts the client-side to encrypt the current page's data before pushing
  it to the history state.
  """
  @spec inertia_encrypt_history(Plug.Conn.t()) :: Plug.Conn.t()
  def inertia_encrypt_history(conn) do
    put_private(conn, :inertia_encrypt_history, true)
  end

  @spec inertia_encrypt_history(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def inertia_encrypt_history(conn, value) when is_boolean(value) do
    put_private(conn, :inertia_encrypt_history, value)
  end

  @doc """
  Instucts the client-side to clear the history state.
  """
  @spec inertia_clear_history(Plug.Conn.t()) :: Plug.Conn.t()
  def inertia_clear_history(conn) do
    put_private(conn, :inertia_clear_history, true)
  end

  @spec inertia_clear_history(Plug.Conn.t(), boolean()) :: Plug.Conn.t()
  def inertia_clear_history(conn, value) when is_boolean(value) do
    put_private(conn, :inertia_clear_history, value)
  end

  @doc """
  Assigns errors to the Inertia page data. This helper accepts any data that
  implements the `Combo.Inertia.Errors` protocol. By default, this library implements
  error serializers for `Ecto.Changeset` and bare maps.

  If you are serializing your own errors maps, they should take the following shape:

      %{
        "name" => "Name is required",
        "password" => "Password must be at least 5 characters",
        "team.name" => "Team name is required",
      }

  When assigning a changeset, you may optionally pass a message-generating function
  to use when traversing errors. See [`Ecto.Changeset.traverse_errors/2`](https://hexdocs.pm/ecto/Ecto.Changeset.html#traverse_errors/2)
  for more information about the message function.

      defp default_msg_func({msg, opts}) do
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{\#{key}}", fn _ -> to_string(value) end)
        end)
      end

  This default implementation performs a simple string replacement for error
  message containing variables, like `count`. For example, given the following
  error:

      {"should be at least %{count} characters", [count: 3, validation: :length, min: 3]}

  The generated description would be "should be at least 3 characters". If you would
  prefer to use the `Gettext` module for pluralizing and localizing error messages, you
  can override the message function:

      conn
      |> inertia_put_errors(changeset, fn {msg, opts} ->
        if count = opts[:count] do
          Gettext.dngettext(MyApp.Web.Gettext, "errors", msg, msg, count, opts)
        else
          Gettext.dgettext(MyApp.Web.Gettext, "errors", msg, opts)
        end
      end)

  """
  @spec inertia_put_errors(Plug.Conn.t(), data :: term()) :: Plug.Conn.t()
  @spec inertia_put_errors(Plug.Conn.t(), data :: term(), msg_func :: function()) ::
          Plug.Conn.t()
  def inertia_put_errors(conn, data) do
    errors =
      data
      |> Errors.to_errors()
      |> bag_errors(conn)
      |> inertia_always()

    inertia_put_prop(conn, :errors, errors)
  end

  def inertia_put_errors(conn, data, msg_func) do
    errors =
      data
      |> Errors.to_errors(msg_func)
      |> bag_errors(conn)
      |> inertia_always()

    inertia_put_prop(conn, :errors, errors)
  end

  defp bag_errors(errors, conn) do
    if error_bag = conn.private[:inertia_error_bag] do
      %{error_bag => errors}
    else
      errors
    end
  end

  @doc """
  Renders an Inertia response.

  ## Options

  - `ssr`: whether to server-side render the response (see the docs on
    "Server-side rendering" in the README for more information on setting this
    up). Defaults to the globally-configured value, or `false` if no global
    config is specified.

  ## Examples

      conn
      |> inertia_put_prop(:user_id, 1)
      |> inertia_render("SettingsPage")

  You may pass additional props as map for the third argument:

      conn
      |> inertia_put_prop(:user_id, 1)
      |> inertia_render("SettingsPage", %{name: "Bob"})

  You may also pass options for the last positional argument:

      conn
      |> inertia_put_prop(:user_id, 1)
      |> inertia_render("SettingsPage", ssr: true)

      conn
      |> inertia_put_prop(:user_id, 1)
      |> inertia_render("SettingsPage", %{name: "Bob"}, ssr: true)
  """

  @spec inertia_render(Plug.Conn.t(), component()) :: Plug.Conn.t()
  def inertia_render(%Plug.Conn{} = conn, component) do
    build_inertia_response(conn, component, %{}, [])
  end

  @spec inertia_render(Plug.Conn.t(), component(), props() | render_opts()) :: Plug.Conn.t()
  def inertia_render(%Plug.Conn{} = conn, component, props) when is_map(props) do
    build_inertia_response(conn, component, props, [])
  end

  def inertia_render(%Plug.Conn{} = conn, component, opts) when is_list(opts) do
    build_inertia_response(conn, component, %{}, opts)
  end

  @spec inertia_render(Plug.Conn.t(), component(), props(), render_opts()) :: Plug.Conn.t()
  def inertia_render(%Plug.Conn{} = conn, component, props, opts)
      when is_map(props) and is_list(opts) do
    build_inertia_response(conn, component, props, opts)
  end

  defp build_inertia_response(conn, component, props, opts) do
    shared_props = conn.private[:inertia_shared] || %{}

    # Only render partial props if the partial component matches the current page
    is_partial = conn.private[:inertia_partial_component] == component
    only = if is_partial, do: conn.private[:inertia_partial_only], else: []
    except = if is_partial, do: conn.private[:inertia_partial_except], else: []
    camelize_props = conn.private[:inertia_camelize_props]
    reset = conn.private[:inertia_reset] || []

    opts = Keyword.merge(opts, camelize_props: camelize_props, reset: reset)

    props = Map.merge(shared_props, props)
    {props, merge_props, deep_merge_props} = resolve_merge_props(props, opts)
    {props, deferred_props} = resolve_deferred_props(props)

    props =
      props
      |> apply_filters(only, except, opts)
      |> resolve_props(opts)
      |> maybe_put_flash(conn)

    conn
    |> put_private(:inertia_page, %{
      component: component,
      props: props,
      merge_props: merge_props,
      deep_merge_props: deep_merge_props,
      deferred_props: deferred_props,
      is_partial: is_partial
    })
    |> detect_ssr(opts)
    |> put_csrf_cookie()
    |> send_response()
  end

  @doc """
  Determines if a response has been rendered with Inertia.
  """
  @spec inertia_response?(Plug.Conn.t()) :: boolean()
  def inertia_response?(%Plug.Conn{private: %{inertia_page: _}} = _conn), do: true
  def inertia_response?(_), do: false

  @doc """
  Forces the Inertia client side to perform a redirect. This can be used as a
  plug or inline when building a response.

  This plug modifies the response to be a 409 Conflict response and include the
  destination URL in the `x-inertia-location` header, which will cause the
  Inertia client to perform a `window.location = url` visit.

  **Note**: we automatically convert regular external redirects (via the Combo
  `redirect` helper), but this function is useful if you need to force redirect
  to a non-external route that is not handled by Inertia.

  See https://inertiajs.com/redirects#external-redirects

  ## Examples

      conn
      |> inertia_force_redirect()
      |> redirect(to: "/non-inertia-powered-page")

  """
  @spec inertia_force_redirect(Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def inertia_force_redirect(conn, _opts \\ []) do
    put_private(conn, :inertia_force_redirect, true)
  end

  # Private helpers

  # Runs a reduce operation over the top-level props and looks for values that
  # were tagged via the `inertia_merge/2` helper. If the value is tagged, then
  # place the key in an array (unless that key is included in the list of
  # "reset" keys). Otherwise, make no modification.
  defp resolve_merge_props(props, opts) do
    Enum.reduce(props, {[], [], []}, fn {key, value}, {props, merge_keys, deep_merge_keys} ->
      transformed_key =
        key
        |> transform_key(opts)
        |> to_string()

      # Only include this key in the collection of merge prop keys
      # if it's not in the "reset" list
      case {transformed_key in opts[:reset], value} do
        {true, {tag, unwrapped_value}} when tag in [:merge, :deep_merge] ->
          {[{key, unwrapped_value} | props], merge_keys, deep_merge_keys}

        {_, {:merge, unwrapped_value}} ->
          {[{key, unwrapped_value} | props], [key | merge_keys], deep_merge_keys}

        {_, {:deep_merge, unwrapped_value}} ->
          {[{key, unwrapped_value} | props], merge_keys, [key | deep_merge_keys]}

        _ ->
          {[{key, value} | props], merge_keys, deep_merge_keys}
      end
    end)
  end

  defp resolve_deferred_props(props) do
    Enum.reduce(props, {[], %{}}, fn {key, value}, {props, keys} ->
      case value do
        {:defer, {fun, group}} ->
          keys =
            case Map.get(keys, group) do
              [_ | _] = group_keys -> Map.put(keys, group, [key | group_keys])
              _ -> Map.put(keys, group, [key])
            end

          {[{key, {:optional, fun}} | props], keys}

        _ ->
          {[{key, value} | props], keys}
      end
    end)
  end

  defp apply_filters(props, only, _except, opts) when length(only) > 0 do
    props
    |> Enum.filter(fn {key, value} ->
      case value do
        {:always, _} ->
          true

        _ ->
          transformed_key =
            key
            |> transform_key(opts)
            |> to_string()

          Enum.member?(only, transformed_key)
      end
    end)
    |> Map.new()
  end

  defp apply_filters(props, _only, except, opts) when length(except) > 0 do
    props
    |> Enum.filter(fn {key, value} ->
      case value do
        {:always, _} ->
          true

        _ ->
          transformed_key =
            key
            |> transform_key(opts)
            |> to_string()

          !Enum.member?(except, transformed_key)
      end
    end)
    |> Map.new()
  end

  defp apply_filters(props, _only, _except, _opts) do
    props
    |> Enum.filter(fn {_key, value} ->
      case value do
        {:optional, _} -> false
        _ -> true
      end
    end)
    |> Map.new()
  end

  defp resolve_props(map, opts) when is_map(map) and not is_struct(map) do
    map
    |> Enum.reduce([], fn {key, value}, acc ->
      [{transform_key(key, opts), resolve_props(value, opts)} | acc]
    end)
    |> Map.new()
  end

  defp resolve_props(list, opts) when is_list(list) do
    Enum.map(list, &resolve_props(&1, opts))
  end

  defp resolve_props({:optional, value}, opts), do: resolve_props(value, opts)
  defp resolve_props({:always, value}, opts), do: resolve_props(value, opts)
  defp resolve_props({:merge, value}, opts), do: resolve_props(value, opts)
  defp resolve_props(fun, opts) when is_function(fun, 0), do: resolve_props(fun.(), opts)
  defp resolve_props(value, _opts), do: value

  # Applies any specified transformations to the key (such as conversion to
  # camel case), unless the key has been marked as "preserved".
  defp transform_key({:preserve, key}, _opts), do: key

  defp transform_key(key, opts) do
    if opts[:camelize_props] do
      key
      |> to_string()
      |> Combo.Naming.camelize(:lower)
      |> atomize_if(is_atom(key))
    else
      key
    end
  end

  defp atomize_if(value, true), do: String.to_atom(value)
  defp atomize_if(value, false), do: value

  # Skip putting flash in the props if there's already `:flash` key assigned.
  # Otherwise, put the flash in the props.
  defp maybe_put_flash(%{flash: _} = props, _conn), do: props
  defp maybe_put_flash(props, conn), do: Map.put(props, :flash, conn.assigns.flash)

  defp send_response(%{private: %{inertia_request: true}} = conn) do
    conn
    |> put_status(200)
    |> put_resp_header("x-inertia", "true")
    |> put_resp_header("vary", "X-Inertia")
    |> json(build_page_object(conn))
  end

  defp send_response(conn) do
    if conn.private[:inertia_ssr] do
      endpoint = endpoint_module!(conn)

      case SSR.call(endpoint, build_page_object(conn)) do
        {:ok, %{"head" => head, "body" => body}} ->
          send_ssr_response(conn, head, body)

        {:error, message} ->
          if raise_on_ssr_failure?(endpoint) do
            raise RenderError, message: message
          else
            Logger.error("SSR failed, falling back to CSR\n\n#{message}")
            send_csr_response(conn)
          end
      end
    else
      send_csr_response(conn)
    end
  end

  defp compile_head(%{assigns: %{inertia_head: current_head}} = conn, incoming_head) do
    {titles, other_tags} = Enum.split_with(current_head ++ incoming_head, &(&1 =~ @title_regex))

    conn
    |> assign(:inertia_head, other_tags)
    |> update_page_title(Enum.reverse(titles))
  end

  defp update_page_title(conn, [title_tag | _]) do
    [_, page_title] = Regex.run(@title_regex, title_tag)
    assign(conn, :page_title, page_title)
  end

  defp update_page_title(conn, _), do: conn

  defp send_ssr_response(conn, head, body) do
    conn
    |> put_view(html: Combo.Inertia.HTML)
    |> compile_head(head)
    |> render(:ssr_content, %{body: body})
  end

  defp send_csr_response(conn) do
    conn
    |> put_view(html: Combo.Inertia.HTML)
    |> render(:csr_content, %{page: build_page_object(conn)})
  end

  # see https://inertiajs.com/the-protocol#the-page-object
  defp build_page_object(conn) do
    %{
      component: conn.private.inertia_page.component,
      props: conn.private.inertia_page.props,
      url: request_path(conn),
      version: conn.private.inertia_version,
      encryptHistory: conn.private.inertia_encrypt_history,
      clearHistory: conn.private.inertia_clear_history
    }
    |> maybe_put_merge_props(conn)
    |> maybe_put_deep_merge_props(conn)
    |> maybe_put_deferred_props(conn)
  end

  defp maybe_put_merge_props(assigns, conn) do
    merge_props = conn.private.inertia_page.merge_props

    if Enum.empty?(merge_props) do
      assigns
    else
      Map.put(assigns, :mergeProps, merge_props)
    end
  end

  defp maybe_put_deep_merge_props(assigns, conn) do
    deep_merge_props = conn.private.inertia_page.deep_merge_props

    if Enum.empty?(deep_merge_props) do
      assigns
    else
      Map.put(assigns, :deepMergeProps, deep_merge_props)
    end
  end

  defp maybe_put_deferred_props(assigns, conn) do
    is_partial = conn.private.inertia_page.is_partial
    deferred_props = conn.private.inertia_page.deferred_props

    if is_partial || Enum.empty?(deferred_props) do
      assigns
    else
      Map.put(assigns, :deferredProps, deferred_props)
    end
  end

  defp request_path(conn) do
    IO.iodata_to_binary([conn.request_path, request_url_qs(conn.query_string)])
  end

  defp request_url_qs(""), do: ""
  defp request_url_qs(qs), do: [??, qs]

  defp put_csrf_cookie(conn) do
    put_resp_cookie(conn, "XSRF-TOKEN", get_csrf_token(), http_only: false)
  end

  defp detect_ssr(conn, opts) do
    value =
      if opts[:ssr] do
        true
      else
        endpoint = endpoint_module!(conn)
        ssr_enabled_globally?(endpoint)
      end

    put_private(conn, :inertia_ssr, value)
  end

  defp ssr_enabled_globally?(endpoint) do
    Config.get(endpoint, :ssr, false)
  end

  defp raise_on_ssr_failure?(endpoint) do
    Config.get(endpoint, :raise_on_ssr_failure, true)
  end
end
