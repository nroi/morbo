defmodule ResourceTest do
  use ExUnit.Case
  doctest Resource

  setup do
    resource_pool = start_supervised!(Resource.ResourcePool)
    %{resource_pool: resource_pool}
  end

  test "test resource pool", %{resource_pool: resource_pool} do
    assert true
  end
end
