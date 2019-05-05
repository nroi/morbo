defmodule ResourceTest do
  use ExUnit.Case
  doctest Resource

  setup do
    init_state = %Resource.ResourcePool{
      seed_to_spawn: fn seed -> {:spawned, seed} end,
      transfer_ownership_to: fn _new_pid, spawn -> :ok end,
      resources: []
    }

    resource_pool = start_supervised!({Resource.ResourcePool, init_state})
    %{resource_pool: resource_pool}
  end

  test "resource newly spawned", %{resource_pool: resource_pool} do
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
    :ok = Resource.ResourcePool.release_resource(:seed)
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
  end
end
