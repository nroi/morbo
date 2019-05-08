defmodule EyepatchResourceTest do
  use ExUnit.Case
  require Logger

  @uri "https://ident.me"
  @remove_resource_after 250

  setup do
    init_state = get_init_state()
    resource_pool = start_supervised!({Morbo.ResourcePool, init_state})
    %{resource_pool: resource_pool}
  end

  defp connect_hackney_inet(), do: &connect_hackney(&1, &2, :inet, &3, &4, &5)
  defp connect_hackney_inet6(), do: &connect_hackney(&1, &2, :inet6, &3, &4, &5)


  def connect_hackney(uri, ip_address, protocol, connect_timeout, _headers, _pid) do
    # TODO _headers are ignored, perhaps this is a symptom of a design issue.
    ip_address =
      case :inet.ntoa(ip_address) do
        {:error, :einval} -> raise("Unable to parse ip address: #{inspect(ip_address)}")
        x -> x
      end
    Logger.debug("ip is: #{inspect ip_address}, protocol: #{protocol}")

    opts = [connect_timeout: connect_timeout, ssl_options: [{:verify, :verify_none}]]
    transport = case uri.port do
      80 -> :hackney_tcp
      443 -> :hackney_ssl
    end
    case :hackney.connect(transport, ip_address, uri.port, opts) do
      {:ok, conn_ref} ->
        Logger.debug("Successfully connected to #{uri.host} via #{inspect ip_address}")
        {:ok, {protocol, conn_ref}}
      {:error, reason} ->
        Logger.warn("Error while attempting to connect to #{uri.host}: #{inspect(reason)}")
        {:error, {protocol, reason}}
    end
  end

  def seed_to_spawn(hostname) do
    Eyepatch.resolve(
      hostname,
      connect_hackney_inet(),
      connect_hackney_inet6(),
      &:inet.getaddrs/2,
      [],
      nil,
      &transfer_ownership_to/2
    )
  end

  def transfer_ownership_to(new_pid, {:ok, {protocol, conn_ref}}) do
    :hackney.controlling_process(conn_ref, new_pid)
  end

  def transfer_ownership_to(new_pid, {:error, _}) do
    :ok
  end

  def close_spawn({:ok, {protocol, conn_ref}}) do
    :ok = :hackney.close(conn_ref)
  end

  def get_init_state() do
    %Morbo.ResourcePool{
      seed_to_spawn: &seed_to_spawn/1,
      transfer_ownership_to: &transfer_ownership_to/2,
      close_spawn: &close_spawn/1,
      resources: [],
      remove_resource_after: @remove_resource_after
    }
  end

  test "connection fetched from existing connection (eyepatch)" do
    {:new_spawn, result} = Morbo.ResourcePool.resource_request(@uri)
    {:ok, {_protocol, conn_ref}} = result
    :ok = Morbo.ResourcePool.release_resource(@uri)
    {:existing_spawn, {:ok, {_protocol, ^conn_ref}}} = Morbo.ResourcePool.resource_request(@uri)
    :ok = Morbo.ResourcePool.release_resource(@uri)
  end

  @tag :wip
  test "Execute some GET requests (eyepatch)", %{resource_pool: _resource_pool} do
    {:new_spawn, result} = Morbo.ResourcePool.resource_request(@uri)
    {:ok, {_protocol, conn_ref}} = result
    request = {:get, "/", [], ""}
    for _ <- 1..10 do
      {:ok, _, _, conn_ref} = :hackney.send_request(conn_ref, request)
      {:ok, body} = :hackney.body(conn_ref)
      Logger.debug("body: #{inspect body}")
    end
    :ok = Morbo.ResourcePool.release_resource(@uri)
  end
end
