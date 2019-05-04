defmodule Resource.ResourcePool do
  alias Resource.ResourcePool
  use GenServer
  require Logger
  defstruct seed_to_resource: nil,
            resources: []


  def start_link(initial_state = %Resource.ResourcePool{}) do
    GenServer.start_link(__MODULE__, initial_state, [])
  end

  @impl true
  def init(initial_state) do
    Logger.debug("Starting gen_server with #{inspect initial_state}")
    # default implementation to avoid warning.
    {:ok, %{}}
  end

  @impl true
  def handle_call({:resource_request, seed}, {from_pid, _tag}, state = %ResourcePool{}) do
    Logger.debug("Resource requested: #{inspect seed}")
    {:reply, :ok, state}
  end

end