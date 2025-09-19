defmodule MyAppWeb.Layouts do
  @moduledoc false

  use MyAppWeb, :html

  import Combo.Inertia.HTML

  embed_templates "layouts/*"
end
