defmodule GovSim.Events.Event do
  @moduledoc """
  Event struct: time, type, entity_id, payload.
  """

  defstruct [
    :time,
    :type,
    :entity_id,
    payload: %{}
  ]

  @type t :: %__MODULE__{
          time: integer(),
          type: atom(),
          entity_id: atom() | nil,
          payload: map()
        }

  def new(time, type, entity_id \\ nil, payload \\ %{}) do
    %__MODULE__{time: time, type: type, entity_id: entity_id, payload: payload}
  end
end
