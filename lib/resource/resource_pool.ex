defmodule Resource.ResourcePool do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(args) do
    # default implementation to avoid warning.
    {:ok, args}
  end

end