defmodule ResourceTest do
  use ExUnit.Case
  doctest Resource

  test "greets the world" do
    assert Resource.hello() == :world
  end
end
