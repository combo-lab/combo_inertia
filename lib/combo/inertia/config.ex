defmodule Combo.Inertia.Config do
  @moduledoc false

  @namespace :inertia

  @spec fetch_endpoint!(Plug.Conn.t()) :: module()
  def fetch_endpoint!(conn) do
    Map.fetch!(conn.private, :phoenix_endpoint)
  end

  @spec get(module(), atom(), any()) :: any()
  def get(endpoint, key, default \\ nil) do
    otp_app(endpoint)
    |> Application.get_env(endpoint, [])
    |> Keyword.get(@namespace, [])
    |> Keyword.get(key, default)
  end

  @spec put(module(), atom(), any()) :: :ok
  def put(endpoint, key, value) do
    otp_app = otp_app(endpoint)

    endpoint_value = Application.get_env(otp_app, endpoint, [])
    endpoint_value = Keyword.put_new(endpoint_value, :inertia, [])
    inertia_value = Keyword.put(endpoint_value[:inertia], key, value)
    endpoint_value = Keyword.put(endpoint_value, :inertia, inertia_value)

    Application.put_env(otp_app, endpoint, endpoint_value)
  end

  defp otp_app(endpoint), do: endpoint.config(:otp_app)
end
