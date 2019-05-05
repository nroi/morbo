defmodule ResourceTest do
  use ExUnit.Case
  doctest Resource

  setup do
    init_state = %Resource.ResourcePool{
      seed_to_spawn: fn seed -> {:spawned, seed} end,
      transfer_ownership_to: fn _new_pid, spawn -> :ok end,
      close_spawn: fn spawn -> :ok end,
      resources: []
    }

    resource_pool = start_supervised!({Resource.ResourcePool, init_state})
    %{resource_pool: resource_pool}
  end

  test "spawn fetched from existing spawn", %{resource_pool: resource_pool} do
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
    :ok = Resource.ResourcePool.release_resource(:seed1)
    {:existing_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
  end

  test "new spawn created when previous spawn still locked", %{resource_pool: resource_pool} do
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
  end

  test "new spawn created after a previous spawn released", %{resource_pool: resource_pool} do
    {:new_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
    :ok = Resource.ResourcePool.release_resource(:seed1)
    {:new_spawn, {:spawned, :seed2}} = Resource.ResourcePool.resource_request(:seed2)
  end

  test "resource released when release holder has crashed" do
    task = Task.async(fn ->
      Resource.ResourcePool.resource_request(:seed1)
    end)
    {:new_spawn, {:spawned, :seed1}} = Task.await(task)
    {:existing_spawn, {:spawned, :seed1}} = Resource.ResourcePool.resource_request(:seed1)
  end

end
