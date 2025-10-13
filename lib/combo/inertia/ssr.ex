defmodule Combo.Inertia.SSR do
  @moduledoc """
  The supervisor that provides SSR support for Inertia views.

  This module is responsible for starting a pool of Node.js processes that
  can run the SSR rendering function for your application.
  """

  use Supervisor

  require Logger

  @default_pool_size 4
  @default_module "ssr"

  @doc """
  Starts the Node.js supervisor and workers for SSR.

  ## Options

  - `:endpoint` - (required) the Combo endpoint.
  - `:path` - (required) the path to the directory where the Node.js module file lives.
  - `:module` - (optional) the name of the Node.js module file. Defaults to "#{@default_module}".
  - `:pool_size` - (optional) the number of Node.js workers. Defaults to #{@default_pool_size}.

  """
  def start_link(init_arg) do
    endpoint = Keyword.fetch!(init_arg, :endpoint)
    path = Keyword.fetch!(init_arg, :path)
    module = Keyword.get(init_arg, :module, @default_module)
    pool_size = Keyword.get(init_arg, :pool_size, @default_pool_size)

    supervisor_name = supervisor_name(endpoint)

    :persistent_term.put({supervisor_name, :module}, module)

    init_arg = [
      name: supervisor_name,
      pool_size: pool_size,
      path: path,
      module: module
    ]

    Supervisor.start_link(__MODULE__, init_arg, name: supervisor_name)
  end

  @impl true
  def init(opts) do
    NodeJS.Supervisor.init(opts)
  end

  @doc false
  def call(endpoint, page) do
    supervisor_name = supervisor_name(endpoint)
    module = :persistent_term.get({supervisor_name, :module})
    NodeJS.call({module, :render}, [page], name: supervisor_name, binary: true)
  end

  defp supervisor_name(endpoint) do
    Module.concat(endpoint, InertiaSSR.Supervisor)
  end
end
