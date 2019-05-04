defmodule Resource.ResourcePool do
  alias Resource.ResourcePool
  use GenServer
  require Logger

  defstruct seed_to_spawn: nil,
            resources: []

  def start_link(initial_state = %Resource.ResourcePool{}) do
    GenServer.start_link(__MODULE__, initial_state, [])
  end

  @impl true
  def init(initial_state) do
    Logger.debug("Starting gen_server with #{inspect(initial_state)}")
    # default implementation to avoid warning.
    {:ok, %{}}
  end

  @impl true
  def handle_call({:resource_request, seed}, {from_pid, _tag}, state = %ResourcePool{}) do
    Logger.debug("Resource requested: #{inspect(seed)}")

    maybe_spawn =
      Enum.find(state.resources, fn
        %Resource{state: :inactive, spawn: spawn} -> spawn
        %Resource{} -> nil
      end)

    spawn =
      case maybe_spawn do
        nil ->
          Logger.debug("No spawn exists for this seed: Create a new one.")
          state.seed_to_spawn.(seed)

        s ->
          s
      end

    {:reply, :ok, state}
  end
end
