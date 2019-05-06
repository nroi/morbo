defmodule Resource.ResourcePool do
  alias Resource.ResourcePool
  use GenServer
  require Logger

  defstruct seed_to_spawn: nil,
            close_spawn: nil,
            transfer_ownership_to: nil,
            resources: [],
            remove_resource_after: nil

  def start_link(initial_state = %Resource.ResourcePool{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def resource_request(seed) do
    GenServer.call(__MODULE__, {:resource_request, seed})
  end

  def release_resource(seed) do
    GenServer.call(__MODULE__, {:release_resource, seed})
  end

  defp release_resource_from_state(pid, state = %ResourcePool{}) do
    Logger.debug("Looking for resource with pid #{inspect(pid)}. State is #{inspect(state)}")

    {resources_unchanged, resources_to_release} =
      Enum.split_with(state.resources, fn
        %Resource{owner: {_ref, ^pid}} -> false
        %Resource{} -> true
      end)

    released_resources =
      Enum.map(resources_to_release, fn r = %Resource{state: :locked} ->
        %{r | state: :released}
      end)

    Enum.each(released_resources, fn r = %Resource{owner: {ref, _pid}, spawn: spawn} ->
      state.transfer_ownership_to.(self(), spawn)
      true = Process.demonitor(ref)
      Process.send_after(self(), {:remove_resource, r}, state.remove_resource_after)
    end)

    Logger.debug("Released resources: #{inspect(released_resources)}")

    new_resources = resources_unchanged ++ released_resources
    %ResourcePool{state | resources: new_resources}
  end

  @impl true
  def init(initial_state) do
    Logger.debug("Starting gen_server with #{inspect(initial_state)}")
    # default implementation to avoid warning.
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:resource_request, seed}, {from_pid, _tag}, state = %ResourcePool{}) do
    Logger.debug("Resource requested: #{inspect(seed)}")

    maybe_resource =
      Enum.find(state.resources, fn
        %Resource{state: :released, seed: ^seed} -> true
        %Resource{} -> false
      end)

    resources_to_remove =
      case maybe_resource do
        nil -> []
        r = %Resource{} -> [r]
      end

    annotated_spawn =
      case maybe_resource do
        nil ->
          Logger.debug("No released resource exists for this seed: Creating a new one.")
          new_spawn = state.seed_to_spawn.(seed)
          state.transfer_ownership_to.(from_pid, new_spawn)
          {:new_spawn, new_spawn}

        %Resource{spawn: spawn} ->
          {:existing_spawn, spawn}
      end

    {annotation, spawn} = annotated_spawn

    ref = Process.monitor(from_pid)

    new_resource = %Resource{
      state: :locked,
      seed: seed,
      spawn: spawn,
      owner: {ref, from_pid}
    }

    Logger.debug("Storing new resource with pid #{inspect(from_pid)}")

    existing_resources =
      Enum.filter(state.resources, fn r = %Resource{} ->
        not Enum.member?(resources_to_remove, r)
      end)

    new_resources = [new_resource | existing_resources]
    new_state = %ResourcePool{state | resources: new_resources}

    new_len =
      case annotation do
        :new_spawn -> Enum.count(state.resources) + 1
        :existing_spawn -> Enum.count(state.resources)
      end

    # Assertion: the new number of resources has either not changed, or increased by 1.
    :ok =
      case Enum.count(new_resources) do
        ^new_len -> :ok
      end

    {:reply, annotated_spawn, new_state}
  end

  @impl true
  def handle_call({:release_resource, _seed}, {pid, _tag}, state = %ResourcePool{}) do
    new_state = release_resource_from_state(pid, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, status}, state = %ResourcePool{}) do
    Logger.warn("Process went down with status #{inspect(status)}")
    new_state = release_resource_from_state(pid, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:remove_resource, r = %Resource{}}, state = %ResourcePool{}) do
    Logger.debug("Remove resource: #{inspect(r)}")
    new_resources = List.delete(state.resources, r)
    new_state = %ResourcePool{state | resources: new_resources}
    state.close_spawn.(r.spawn)
    {:noreply, new_state}
  end
end
