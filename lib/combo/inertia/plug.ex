defmodule Combo.Inertia.Plug do
  @moduledoc """
  The plug for detecting Inertia requests and preparing the connection
  accordingly.
  """

  import Plug.Conn
  import Combo.Conn, only: [endpoint_module!: 1]

  import Combo.Inertia.Conn,
    only: [
      inertia_encrypt_history: 2,
      inertia_clear_history: 2,
      inertia_camelize_props: 2,
      inertia_put_errors: 2
    ]

  alias Combo.Inertia.Config
  alias Combo.Inertia.Cache

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    endpoint = endpoint_module!(conn)

    conn
    |> assign(:inertia_head, [])
    |> assign(:inertia_ssr, global_ssr?(endpoint))
    |> put_private(:inertia_version, compute_version(endpoint))
    |> inertia_encrypt_history(global_encrypt_history?(endpoint))
    |> inertia_clear_history(false)
    |> inertia_camelize_props(global_camelize_props?(endpoint))
    |> put_private(:inertia_error_bag, get_error_bag(conn))
    |> merge_forwarded_flash()
    |> fetch_inertia_errors()
    |> detect_inertia()
  end

  defp fetch_inertia_errors(conn) do
    errors = get_session(conn, "inertia_errors") || %{}
    conn = inertia_put_errors(conn, errors)

    register_before_send(conn, fn %{status: status} = conn ->
      props = conn.private[:inertia_shared] || %{}

      errors =
        case props[:errors] do
          {:always, data} -> data
          _ -> %{}
        end

      # Keep errors if we are responding with a traditional redirect (301..308)
      # or a force refresh (409) and there are some errors set
      if (status in 300..308 or status == 409) and map_size(errors) > 0 do
        put_session(conn, "inertia_errors", errors)
      else
        delete_session(conn, "inertia_errors")
      end
    end)
  end

  defp detect_inertia(conn) do
    case get_req_header(conn, "x-inertia") do
      ["true"] ->
        endpoint = endpoint_module!(conn)

        conn
        |> put_private(:inertia_version, compute_version(endpoint))
        |> put_private(:inertia_request, true)
        |> detect_partial_reload()
        |> detect_reset()
        |> convert_redirects()
        |> check_version()

      _ ->
        conn
    end
  end

  defp detect_partial_reload(conn) do
    case get_req_header(conn, "x-inertia-partial-component") do
      [component] when is_binary(component) ->
        conn
        |> put_private(:inertia_partial_component, component)
        |> put_private(:inertia_partial_only, get_partial_only(conn))
        |> put_private(:inertia_partial_except, get_partial_except(conn))

      _ ->
        conn
    end
  end

  defp detect_reset(conn) do
    resets =
      case get_req_header(conn, "x-inertia-reset") do
        [stringified_list] when is_binary(stringified_list) ->
          String.split(stringified_list, ",")

        _ ->
          []
      end

    put_private(conn, :inertia_reset, resets)
  end

  defp get_partial_only(conn) do
    case get_req_header(conn, "x-inertia-partial-data") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp get_partial_except(conn) do
    case get_req_header(conn, "x-inertia-partial-except") do
      [stringified_list] when is_binary(stringified_list) ->
        String.split(stringified_list, ",")

      _ ->
        []
    end
  end

  defp get_error_bag(conn) do
    case get_req_header(conn, "x-inertia-error-bag") do
      [error_bag] when is_binary(error_bag) -> error_bag
      _ -> nil
    end
  end

  defp convert_redirects(conn) do
    register_before_send(conn, fn %{method: method, status: status} = conn ->
      cond do
        # see: https://inertiajs.com/redirects#external-redirects
        external_redirect?(conn) ->
          [location] = get_resp_header(conn, "location")

          conn
          |> put_status(409)
          |> put_resp_header("x-inertia-location", location)

        # see: https://inertiajs.com/redirects#303-response-code
        method in ["PUT", "PATCH", "DELETE"] and status in [301, 302] ->
          put_status(conn, 303)

        true ->
          conn
      end
    end)
  end

  defp external_redirect?(%{status: status} = conn) when status in 300..308 do
    [location] = get_resp_header(conn, "location")
    conn.private[:inertia_force_redirect] || !String.starts_with?(location, "/")
  end

  defp external_redirect?(_conn), do: false

  @default_version "1"
  defp compute_version(endpoint) do
    Cache.get(endpoint, :assets_version, fn -> {:ok, auto_detect_assets_version(endpoint)} end)
  end

  defp auto_detect_assets_version(endpoint) do
    case global_assets_version(endpoint) do
      :auto ->
        cond do
          hash = vite_manifest_hash(endpoint) -> hash
          hash = combo_static_manifest_hash(endpoint) -> hash
          true -> @default_version
        end

      {module, fun, args} ->
        apply(module, fun, args)

      binary when is_binary(binary) ->
        binary
    end
  end

  # TODO: improve the hardcode
  defp vite_manifest_hash(endpoint) do
    path = Application.app_dir(endpoint.config(:otp_app), "priv/static/build/manifest.json")
    if File.exists?(path), do: hash(path), else: nil
  end

  # TODO: improve the hardcode
  defp combo_static_manifest_hash(endpoint) do
    path = Application.app_dir(endpoint.config(:otp_app), "priv/static/manifest.digest.json")
    if File.exists?(path), do: hash(path), else: nil
  end

  defp hash(path) do
    path
    |> File.read!()
    |> :erlang.phash2()
    |> to_string()
    |> Base.encode64()
  end

  # see: https://inertiajs.com/the-protocol#asset-versioning
  defp check_version(%{private: %{inertia_version: current_version}} = conn) do
    if conn.method == "GET" && get_req_header(conn, "x-inertia-version") != [current_version] do
      force_refresh(conn)
    else
      conn
    end
  end

  defp force_refresh(conn) do
    conn
    |> put_resp_header("x-inertia-location", request_url(conn))
    |> put_resp_content_type("text/html")
    |> forward_flash()
    |> send_resp(:conflict, "")
    |> halt()
  end

  defp forward_flash(%{assigns: %{flash: flash}} = conn)
       when is_map(flash) and map_size(flash) > 0 do
    put_session(conn, "inertia_flash", flash)
  end

  defp forward_flash(conn), do: conn

  defp merge_forwarded_flash(conn) do
    case get_session(conn, "inertia_flash") do
      nil ->
        conn

      flash ->
        conn
        |> delete_session("inertia_flash")
        |> assign(:flash, Map.merge(conn.assigns.flash, flash))
    end
  end

  defp global_assets_version(endpoint) do
    Config.get(endpoint, :assets_version, :auto)
  end

  defp global_encrypt_history?(endpoint) do
    Config.get(endpoint, :encrypt_history, false)
  end

  defp global_camelize_props?(endpoint) do
    Config.get(endpoint, :camelize_props, false)
  end

  defp global_ssr?(endpoint) do
    Config.get(endpoint, :ssr, false)
  end
end
