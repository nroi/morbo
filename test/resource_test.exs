defmodule ResourceTest do
  use ExUnit.Case

  @remove_resource_after_millisecs 10

  setup do
    init_state = %Morbo.ResourcePool{
      seed_to_spawn: fn seed -> {:spawned, seed} end,
      transfer_ownership_to: fn _new_pid, _spawn -> :ok end,
      close_spawn: fn _spawn -> :ok end,
      resources: [],
      remove_resource_after_millisecs: @remove_resource_after_millisecs,
      owner_after_release: self()
    }

    pid = start_supervised!({Morbo.ResourcePool, init_state})
    %{resource_pool: pid}
  end

  test "spawn fetched from existing spawn" do
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    :ok = Morbo.ResourcePool.release_resource(:seed1)
    {:existing_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
  end

  test "new spawn created when previous spawn still locked" do
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
  end

  test "new spawn created after a previous spawn released" do
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    :ok = Morbo.ResourcePool.release_resource(:seed1)
    {:new_spawn, {:spawned, :seed2}} = Morbo.ResourcePool.resource_request(:seed2)
  end

  test "resource removed after time interval elapsed seconds" do
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    :ok = Morbo.ResourcePool.release_resource(:seed1)
    :timer.sleep(@remove_resource_after_millisecs * 2)
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
  end

  test "resource not removed too early" do
    {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    :ok = Morbo.ResourcePool.release_resource(:seed1)
    {:existing_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
    :timer.sleep(@remove_resource_after_millisecs * 2)
    :ok = Morbo.ResourcePool.release_resource(:seed1)
    {:existing_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
  end

  test "resource released when release process has exited" do
    task =
      Task.async(fn ->
        {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
      end)

    {:new_spawn, {:spawned, :seed1}} = Task.await(task)
    {:existing_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
  end

  @tag :wip
  test "No errors occur when the same process acquires two different resources",
       %{resource_pool: pid} do
    task =
      Task.async(fn ->
        {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
        {:new_spawn, {:spawned, :seed2}} = Morbo.ResourcePool.resource_request(:seed2)
        :ok
      end)

    :ok = Task.await(task)
    :timer.sleep(@remove_resource_after_millisecs * 2)

    # assert that the resource pool has not crashed:
    true = Process.alive?(pid)
  end

  @tag :wip
  test "No errors occur when the same process acquires the same resource twice",
       %{resource_pool: pid} do
    task =
      Task.async(fn ->
        {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
        {:new_spawn, {:spawned, :seed1}} = Morbo.ResourcePool.resource_request(:seed1)
        :ok
      end)

    :ok = Task.await(task)
    :timer.sleep(@remove_resource_after_millisecs * 2)

    # assert that the resource pool has not crashed:
    true = Process.alive?(pid)
  end
end
