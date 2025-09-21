defmodule Combo.Inertia.ConnTest do
  use ExUnit.Case, async: true

  import Combo.Inertia.Conn, only: [inertia_optional: 1, inertia_defer: 1, inertia_defer: 2]

  describe "inertia_optional/1" do
    test "tags a value as optional" do
      fun = fn -> 1 end
      assert inertia_optional(fun) == {:optional, fun}
    end
  end

  describe "inertia_defer/1" do
    test "tags as deferred with 'default' group" do
      fun = fn -> 1 end
      assert inertia_defer(fun) == {:defer, {fun, "default"}}
    end
  end

  describe "inertia_defer/2" do
    test "tags as deferred with given group" do
      fun = fn -> 1 end
      assert inertia_defer(fun, "dashboard") == {:defer, {fun, "dashboard"}}
    end
  end
end
