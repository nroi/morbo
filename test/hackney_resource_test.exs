defmodule HackneyResourceTest do
  use ExUnit.Case
  doctest Resource

  @hostname "v4.ident.me"
  @remove_resource_after 250

  setup do
    init_state = get_init_state
    resource_pool = start_supervised!({Resource.ResourcePool, init_state})
    %{resource_pool: resource_pool}
  end

  def get_init_state() do
    %Resource.ResourcePool{
      seed_to_spawn: fn hostname ->
                        {:ok, conn_ref} = :hackney.connect(:hackney_ssl, hostname, 443, [])
                        conn_ref
      end,
      transfer_ownership_to: fn _new_pid, _conn_ref -> :ok end,
      close_spawn: fn conn_ref -> :ok = :hackney.close(conn_ref) end,
      resources: [],
      remove_resource_after: @remove_resource_after
    }
  end

  @tag :wip
  test "connection fetched from existing connection", %{resource_pool: _resource_pool} do
    {:new_spawn, conn_ref} = Resource.ResourcePool.resource_request(@hostname)
    :ok = Resource.ResourcePool.release_resource(@hostname)
    {:existing_spawn, ^conn_ref} = Resource.ResourcePool.resource_request(@hostname)
  end

end