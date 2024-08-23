defmodule HedgexTest do
  use ExUnit.Case
  doctest Hedgex

  test "greets the world" do
    assert Hedgex.hello() == :world
  end
end
