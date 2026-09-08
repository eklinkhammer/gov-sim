defmodule GovSim.Simulation.Engine do
  @moduledoc """
  GenServer: event loop, step/pause/resume/speed, PubSub broadcast.
  Owns the simulation timeline and world state.
  """

  use GenServer

  alias GovSim.Simulation.EventQueue
  alias GovSim.Events.Registry
  alias GovSim.World.World

  @pubsub GovSim.PubSub
  @topic "simulation"

  # Speed: milliseconds between processing events
  @speed_settings %{
    paused: :infinity,
    slow: 500,
    normal: 100,
    fast: 10,
    instant: 0
  }

  defstruct [
    :world,
    :queue,
    speed: :paused,
    events_processed: 0,
    timer_ref: nil
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def step do
    GenServer.call(__MODULE__, :step)
  end

  def step(n) when is_integer(n) and n > 0 do
    GenServer.call(__MODULE__, {:step, n}, 30_000)
  end

  def play(speed \\ :normal) do
    GenServer.cast(__MODULE__, {:play, speed})
  end

  def pause do
    GenServer.cast(__MODULE__, :pause)
  end

  def set_speed(speed) do
    GenServer.cast(__MODULE__, {:set_speed, speed})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc "Inject a player command event at sim_time + 1. Called from LiveView."
  def inject_event(%GovSim.Events.Event{} = event) do
    GenServer.cast(__MODULE__, {:inject_event, event})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    {world, queue} = Keyword.get(opts, :setup, &GovSim.Simulation.Setup.initial_state/0).()

    state = %__MODULE__{
      world: world,
      queue: queue,
      speed: :paused
    }

    broadcast(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, snapshot(state), state}
  end

  def handle_call(:step, _from, state) do
    case process_next_event(state) do
      {:ok, new_state} ->
        broadcast(new_state)
        {:reply, :ok, new_state}

      :empty ->
        {:reply, :empty, state}
    end
  end

  def handle_call({:step, n}, _from, state) do
    new_state =
      Enum.reduce_while(1..n, state, fn _, acc ->
        case process_next_event(acc) do
          {:ok, s} -> {:cont, s}
          :empty -> {:halt, acc}
        end
      end)

    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:reset, _from, _state) do
    {world, queue} = GovSim.Simulation.Setup.initial_state()

    new_state = %__MODULE__{
      world: world,
      queue: queue,
      speed: :paused
    }

    broadcast(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:play, speed}, state) do
    state = cancel_timer(state)
    new_state = %{state | speed: speed}
    new_state = schedule_tick(new_state)
    {:noreply, new_state}
  end

  def handle_cast(:pause, state) do
    state = cancel_timer(state)
    new_state = %{state | speed: :paused}
    broadcast(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:inject_event, event}, state) do
    adjusted_event = %{event | time: state.world.sim_time + 1}
    new_queue = EventQueue.push(state.queue, adjusted_event)
    {:noreply, %{state | queue: new_queue}}
  end

  def handle_cast({:set_speed, speed}, state) do
    state = cancel_timer(state)
    new_state = %{state | speed: speed}

    new_state =
      if speed != :paused do
        schedule_tick(new_state)
      else
        new_state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:tick, state) do
    case process_next_event(state) do
      {:ok, new_state} ->
        broadcast(new_state)
        new_state = schedule_tick(new_state)
        {:noreply, new_state}

      :empty ->
        new_state = %{state | speed: :paused}
        broadcast(new_state)
        {:noreply, new_state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Internal

  # Process all events at the same timestamp as a single "step"
  defp process_next_event(%__MODULE__{queue: queue} = state) do
    case EventQueue.peek(queue) do
      :empty -> :empty
      {:ok, %{time: time}} -> process_all_at_time(state, time)
    end
  end

  defp process_all_at_time(%__MODULE__{queue: queue} = state, time) do
    case EventQueue.peek(queue) do
      {:ok, %{time: ^time}} ->
        {:ok, event, new_queue} = EventQueue.pop(queue)

        case Registry.get_handler(event.type) do
          {:ok, handler} ->
            {new_world, new_events} = handler.handle(event, state.world)
            new_queue = EventQueue.push_many(new_queue, new_events)

            new_state = %{state |
              world: %{new_world | sim_time: event.time},
              queue: new_queue,
              events_processed: state.events_processed + 1
            }

            process_all_at_time(new_state, time)

          {:error, :unknown_event_type} ->
            log_entry = %{
              time: event.time,
              type: :error,
              message: "Unknown event type: #{event.type}"
            }

            new_world = World.log_event(state.world, log_entry)
            process_all_at_time(%{state | world: new_world, queue: new_queue}, time)
        end

      _ ->
        {:ok, state}
    end
  end

  defp schedule_tick(%__MODULE__{speed: :paused} = state), do: state

  defp schedule_tick(%__MODULE__{speed: speed} = state) do
    interval = Map.get(@speed_settings, speed, 100)

    if interval == 0 do
      # Process immediately
      send(self(), :tick)
      state
    else
      ref = Process.send_after(self(), :tick, interval)
      %{state | timer_ref: ref}
    end
  end

  defp cancel_timer(%__MODULE__{timer_ref: nil} = state), do: state

  defp cancel_timer(%__MODULE__{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:simulation_update, snapshot(state)})
  end

  defp snapshot(%__MODULE__{} = state) do
    %{
      world: state.world,
      speed: state.speed,
      events_processed: state.events_processed,
      queue_size: EventQueue.size(state.queue),
      sim_time: state.world.sim_time
    }
  end
end
