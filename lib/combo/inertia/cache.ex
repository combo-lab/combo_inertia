defmodule Combo.Inertia.Cache do
  @moduledoc false
  # It's built on top of `Combo.Cache`.

  def get(endpoint, key, fun) do
    Combo.Cache.get(endpoint, {:combo_inertia, key}, fun)
  end
end
