defmodule Resource.ResourcePool do
  use GenServer
  require Logger

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, [])
  end

  @impl true
  def init(initial_state) do
    Logger.debug("Starting gen_server with #{inspect initial_state}")
    # default implementation to avoid warning.
    {:ok, %{}}
  end

end