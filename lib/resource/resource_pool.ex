defmodule Resource.ResourcePool do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    # default implementation to avoid warning.
    {:ok, %{}}
  end

end