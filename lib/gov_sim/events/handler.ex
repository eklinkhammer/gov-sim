defmodule GovSim.Events.Handler do
  @moduledoc """
  Handler behaviour: handle(event, world) -> {world, [events]}
  """

  alias GovSim.Events.Event
  alias GovSim.World.World

  @callback handle(Event.t(), World.t()) :: {World.t(), [Event.t()]}
end
