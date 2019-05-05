defmodule Resource.ResourcePool do
  alias Resource.ResourcePool
  use GenServer
  require Logger

  defstruct seed_to_spawn: nil,
            transfer_ownership_to: nil,
            resources: []

  def start_link(initial_state = %Resource.ResourcePool{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def resource_request(seed) do
    GenServer.call(__MODULE__, {:resource_request, seed})
  end

  def release_resource(seed) do
    GenServer.call(__MODULE__, {:release_resource, seed})
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

    maybe_spawn =
      Enum.find(state.resources, fn
        %Resource{state: :released, spawn: spawn} -> spawn
        %Resource{} -> nil
      end)

    spawn =
      case maybe_spawn do
        nil ->
          Logger.debug("No released resource exists for this seed: Creating a new one.")
          new_spawn = state.seed_to_spawn.(seed)
          state.transfer_ownership_to.(from_pid, new_spawn)
          {:new_spawn, new_spawn}

        s ->
          {:existing_spawn, s}
      end

    ref = Process.monitor(from_pid)

    new_resource = %Resource{
      state: :locked,
      seed: seed,
      spawn: spawn,
      owner: {ref, from_pid}
    }

    new_state = %{state | resources: [new_resource | state.resources]}

    {:reply, spawn, state}
  end

  @impl true
  def handle_call({:release_resource, seed}, {from_pid, _tag}, state = %ResourcePool{}) do
    # TODO implement.
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, status}, state) do
    Logger.warn("Process went down with status #{inspect(status)}")

    {resources_unchanged, resources_to_release} =
      Enum.split_with(state.resources, fn
        %Resource{owner: {^ref, _pid}} -> false
        %Resource{} -> true
      end)

    Enum.each(resources_to_release, fn %Resource{owner: {ref, _pid}, spawn: spawn} ->
      state.transfer_ownership_to.(self(), spawn)
      true = Process.demonitor(ref)
    end)

    released_resources =
      Enum.map(resources_to_release, fn r = %Resource{state: :locked} ->
        %{r | state: :released}
      end)

    new_resources = resources_unchanged ++ released_resources
    new_state = %{state | resources: new_resources}
    {:noreply, new_state}
  end
end
