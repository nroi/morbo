defmodule ResourceTest do
  use ExUnit.Case
  doctest Resource

  setup do
    initial_state = []

    init_state = %Resource.ResourcePool{
      seed_to_spawn: fn seed -> {:spawned, seed} end,
      transfer_ownership_to: fn _new_pid, spawn -> :ok end,
      resources: []
    }

    resource_pool = start_supervised!({Resource.ResourcePool, init_state})
    %{resource_pool: resource_pool}
  end

  test "test resource pool", %{resource_pool: resource_pool} do
    result = Resource.ResourcePool.resource_request(:seed)
    assert true
  end
end
