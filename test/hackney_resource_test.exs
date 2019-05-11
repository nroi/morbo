defmodule HackneyResourceTest do
  use ExUnit.Case

  @default_resource {"v4.ident.me", 443}
  @remove_resource_after_millisecs 250

  setup do
    init_state = get_init_state()
    start_supervised!({Morbo.ResourcePool, init_state})
    :ok
  end

  def get_init_state() do
    %Morbo.ResourcePool{
      seed_to_spawn: fn {hostname, port} ->
        transport = case port do
          443 -> :hackney_ssl
          80 -> :hackney_tcp
        end
        {:ok, conn_ref} = :hackney.connect(transport, hostname, port, [])
        conn_ref
      end,
      transfer_ownership_to: fn new_pid, conn_ref ->
        :hackney.controlling_process(conn_ref, new_pid)
      end,
      close_spawn: fn conn_ref -> :ok = :hackney.close(conn_ref) end,
      resources: [],
      remove_resource_after_millisecs: @remove_resource_after_millisecs
    }
  end

  test "connection fetched from existing connection" do
    {:new_spawn, conn_ref} = Morbo.ResourcePool.resource_request(@default_resource)
    :ok = Morbo.ResourcePool.release_resource(@default_resource)
    {:existing_spawn, ^conn_ref} = Morbo.ResourcePool.resource_request(@default_resource)
    :ok = Morbo.ResourcePool.release_resource(@default_resource)
  end

  test "Execute some GET requests" do
    {:new_spawn, conn_ref} = Morbo.ResourcePool.resource_request(@default_resource)
    request = {:get, "/", [], ""}
    for _ <- 1..10 do
      {:ok, _, _, conn_ref} = :hackney.send_request(conn_ref, request)
      {:ok, _body} = :hackney.body(conn_ref)
    end
    :ok = Morbo.ResourcePool.release_resource(@default_resource)
  end

  test "Connections are closed gracefully when the resource holder exits" do
    task =
      Task.async(fn ->
        {:new_spawn, _conn_ref} = Morbo.ResourcePool.resource_request(@default_resource)
      end)
    {:new_spawn, conn_ref} = Task.await(task)
    request = {:get, "/", [], ""}
    {:error, :closed} = :hackney.send_request(conn_ref, request)
  end

  test "hackney's connection pool is not exhausted after many requests to the same host" do
    for _ <- 1..100 do
      {_, _conn_ref} = Morbo.ResourcePool.resource_request(@default_resource)
      :ok = Morbo.ResourcePool.release_resource(@default_resource)
    end
  end

  test "hackney's connection pool is not exhausted after many requests to different hosts" do
    for i <- 1..100 do
      hostname = "#{i}.xnet.space"
      resource = {hostname, 80}
      {_, conn_ref} = Morbo.ResourcePool.resource_request(resource)
      request = {:get, "/", [], ""}
      {:ok, _, _, ^conn_ref} = :hackney.send_request(conn_ref, request)
      {:ok, _body} = :hackney.body(conn_ref)
      :ok = Morbo.ResourcePool.release_resource(resource)
    end
  end

  test "Execute some GET requests on a host with keepalive disabled" do
    # Apparently, hackney automatically re-establishes the connection when the
    # socket has been closed by the server. When we enable and disable keepalive
    # on the server, the only noticeable difference is that this test takes longer
    # to complete, but it succeeds in both cases.
    resource = {"nokeepalive.xnet.space", 80}
    {:new_spawn, conn_ref} = Morbo.ResourcePool.resource_request(resource)
    request = {:get, "/", [], ""}
    for _ <- 1..30 do
      {:ok, _, _, conn_ref} = :hackney.send_request(conn_ref, request)
      {:ok, _body} = :hackney.body(conn_ref)
    end
    :ok = Morbo.ResourcePool.release_resource(resource)
  end

end
