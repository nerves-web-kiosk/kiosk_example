defmodule KioskExampleTest do
  use ExUnit.Case
  doctest KioskExample

  test "greets the world" do
    assert KioskExample.hello() == :world
  end
end
