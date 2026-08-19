defmodule GovSim.Simulation.EventQueue do
  @moduledoc """
  Simple sorted-list priority queue for events.
  Events are sorted by time (ascending). At PoC scale this is sufficient.
  """

  defstruct events: []

  @type t :: %__MODULE__{events: [GovSim.Events.Event.t()]}

  def new(events \\ []) do
    %__MODULE__{events: Enum.sort_by(events, & &1.time)}
  end

  @doc "Push an event into the queue, maintaining sort order"
  def push(%__MODULE__{events: events} = queue, %{time: time} = event) do
    {before, after_} = Enum.split_while(events, fn e -> e.time <= time end)
    %{queue | events: before ++ [event | after_]}
  end

  @doc "Push multiple events"
  def push_many(%__MODULE__{} = queue, new_events) do
    Enum.reduce(new_events, queue, &push(&2, &1))
  end

  @doc "Pop the next event. Returns {:ok, event, queue} or :empty"
  def pop(%__MODULE__{events: []}), do: :empty

  def pop(%__MODULE__{events: [first | rest]}) do
    {:ok, first, %__MODULE__{events: rest}}
  end

  @doc "Peek at the next event without removing it"
  def peek(%__MODULE__{events: []}), do: :empty
  def peek(%__MODULE__{events: [first | _]}), do: {:ok, first}

  def size(%__MODULE__{events: events}), do: length(events)

  def empty?(%__MODULE__{events: []}), do: true
  def empty?(_), do: false
end
