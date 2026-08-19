defmodule GovSimWeb.SimulationLive do
  use GovSimWeb, :live_view

  alias GovSim.Simulation.{Engine, Clock}
  alias GovSim.Entities.Inventory

  @topic "simulation"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GovSim.PubSub, @topic)
    end

    state = Engine.get_state()

    {:ok,
     assign(socket,
       world: state.world,
       speed: state.speed,
       events_processed: state.events_processed,
       queue_size: state.queue_size,
       sim_time: state.sim_time,
       selected_decision: nil
     )}
  end

  @impl true
  def handle_event("step", _params, socket) do
    Engine.step()
    {:noreply, socket}
  end

  def handle_event("step-10", _params, socket) do
    Engine.step(10)
    {:noreply, socket}
  end

  def handle_event("step-100", _params, socket) do
    Engine.step(100)
    {:noreply, socket}
  end

  def handle_event("play", %{"speed" => speed}, socket) do
    Engine.play(String.to_existing_atom(speed))
    {:noreply, socket}
  end

  def handle_event("pause", _params, socket) do
    Engine.pause()
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    Engine.reset()
    {:noreply, socket}
  end

  def handle_event("select-decision", %{"index" => index}, socket) do
    idx = String.to_integer(index)
    events = socket.assigns.world.event_log

    decision =
      events
      |> Enum.filter(&Map.has_key?(&1, :decision))
      |> Enum.at(idx)

    {:noreply, assign(socket, selected_decision: decision && decision.decision)}
  end

  def handle_event("clear-decision", _params, socket) do
    {:noreply, assign(socket, selected_decision: nil)}
  end

  @impl true
  def handle_info({:simulation_update, state}, socket) do
    {:noreply,
     assign(socket,
       world: state.world,
       speed: state.speed,
       events_processed: state.events_processed,
       queue_size: state.queue_size,
       sim_time: state.sim_time
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-stone-900 text-stone-100 p-4">
      <header class="mb-6">
        <h1 class="text-2xl font-bold text-amber-400">GovSim: Medieval Household</h1>
        <p class="text-stone-400 text-sm">A bottom-up social simulation</p>
      </header>

      <!-- Controls -->
      <div class="bg-stone-800 rounded-lg p-4 mb-4 flex flex-wrap items-center gap-3">
        <div class="text-lg font-mono text-amber-300">
          {Clock.format(@sim_time)}
        </div>
        <div class="text-sm text-stone-400">
          Events: {@events_processed} | Queue: {@queue_size}
        </div>
        <div class="flex-1"></div>

        <button phx-click="step" class="px-3 py-1 bg-stone-700 hover:bg-stone-600 rounded text-sm">
          Step
        </button>
        <button phx-click="step-10" class="px-3 py-1 bg-stone-700 hover:bg-stone-600 rounded text-sm">
          +10
        </button>
        <button phx-click="step-100" class="px-3 py-1 bg-stone-700 hover:bg-stone-600 rounded text-sm">
          +100
        </button>

        <%= if @speed == :paused do %>
          <button phx-click="play" phx-value-speed="slow" class="px-3 py-1 bg-green-800 hover:bg-green-700 rounded text-sm">
            Slow
          </button>
          <button phx-click="play" phx-value-speed="normal" class="px-3 py-1 bg-green-700 hover:bg-green-600 rounded text-sm">
            Play
          </button>
          <button phx-click="play" phx-value-speed="fast" class="px-3 py-1 bg-green-600 hover:bg-green-500 rounded text-sm">
            Fast
          </button>
        <% else %>
          <button phx-click="pause" class="px-3 py-1 bg-red-800 hover:bg-red-700 rounded text-sm">
            Pause ({@speed})
          </button>
        <% end %>

        <button phx-click="reset" class="px-3 py-1 bg-stone-700 hover:bg-red-800 rounded text-sm">
          Reset
        </button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Household Panel -->
        <div class="lg:col-span-1 space-y-4">
          <!-- Persons -->
          <div class="bg-stone-800 rounded-lg p-4">
            <h2 class="text-lg font-semibold text-amber-400 mb-3">Household Members</h2>
            <%= for {_id, person} <- @world.persons do %>
              <div class={["mb-3 p-2 rounded border", if(person.alive, do: "bg-stone-750 border-stone-700", else: "bg-red-950 border-red-900 opacity-60")]}>
                <div class="flex justify-between items-center mb-1">
                  <span class="font-medium">{person.name}</span>
                  <%= if person.alive do %>
                    <span class="text-xs text-stone-400">Age {person.age}</span>
                  <% else %>
                    <span class="text-xs text-red-400">Dead</span>
                  <% end %>
                </div>
                <%= if person.alive do %>
                  <div class="space-y-1">
                    <.bar label="Hunger" value={person.hunger} color="red" />
                    <.bar label="Energy" value={person.energy} color="green" />
                    <.bar label="Labor" value={person.labor_capacity} color="blue" />
                  </div>
                  <div class="text-xs text-stone-400 mt-1">
                    <%= if person.current_task do %>
                      <span class="text-amber-400">{task_label(person.current_task)}</span>
                    <% else %>
                      Idle
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Inventory -->
          <div class="bg-stone-800 rounded-lg p-4">
            <h2 class="text-lg font-semibold text-amber-400 mb-3">Granary</h2>
            <%= for {_id, hh} <- @world.households do %>
              <div class="text-sm">
                <div class="flex justify-between">
                  <span>Wheat</span>
                  <span class="font-mono text-amber-300">
                    {Float.round(Inventory.get(hh.inventory, :wheat_bushels), 2)} bushels
                  </span>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Parcels -->
          <div class="bg-stone-800 rounded-lg p-4">
            <h2 class="text-lg font-semibold text-amber-400 mb-3">Fields</h2>
            <%= for {_id, parcel} <- @world.parcels do %>
              <div class="mb-2 p-2 bg-stone-750 rounded border border-stone-700">
                <div class="flex justify-between">
                  <span class="font-medium">{parcel.name}</span>
                  <span class="text-xs text-stone-400">{parcel.acres} acres</span>
                </div>
                <div class="text-sm">
                  State: <span class={parcel_state_color(parcel.state)}>{parcel.state}</span>
                  <%= if parcel.crop do %>
                    | Crop: {parcel.crop}
                  <% end %>
                </div>
                <%= if parcel.state in [:planted, :growing] and parcel.planted_at do %>
                  <.bar label="Growth" value={GovSim.Systems.Agriculture.growth_progress(parcel.planted_at, @sim_time)} color="emerald" />
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Event Log -->
        <div class="lg:col-span-1 bg-stone-800 rounded-lg p-4">
          <h2 class="text-lg font-semibold text-amber-400 mb-3">Event Log</h2>
          <div class="space-y-1 max-h-[600px] overflow-y-auto text-sm font-mono">
            <%= for entry <- Enum.take(@world.event_log, 100) do %>
              <div class={"py-1 border-b border-stone-700 #{event_color(entry)}"}>
                <span class="text-stone-500">[{Clock.format(entry.time)}]</span>
                <span class={"ml-1 #{system_badge(entry)}"}>[{event_system(entry)}]</span>
                {entry.message}
                <%= if Map.has_key?(entry, :decision) do %>
                  <button
                    phx-click="select-decision"
                    phx-value-index={decision_index(@world.event_log, entry)}
                    class="ml-1 text-xs text-amber-500 hover:text-amber-300 underline"
                  >
                    inspect
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Decision Inspector -->
        <div class="lg:col-span-1 bg-stone-800 rounded-lg p-4">
          <h2 class="text-lg font-semibold text-amber-400 mb-3">Decision Inspector</h2>
          <%= if @selected_decision do %>
            <div class="space-y-3">
              <div class="text-lg">
                <span class="font-medium">{@selected_decision.person}</span>
                decided to
                <span class={if @selected_decision.decision == :accept, do: "text-green-400", else: "text-red-400"}>
                  {@selected_decision.decision}
                </span>
              </div>
              <div class="text-sm text-stone-400">
                Score: <span class="font-mono text-amber-300">{@selected_decision.score}</span>
              </div>
              <div class="space-y-2">
                <h3 class="text-sm font-semibold text-stone-300">Factors:</h3>
                <%= for {name, value, weight} <- @selected_decision.factors do %>
                  <div class="flex items-center gap-2 text-sm">
                    <span class="w-24 text-stone-400">{name}</span>
                    <div class="flex-1 bg-stone-700 rounded h-4 relative">
                      <div
                        class={[
                          "h-full rounded",
                          if(value >= 0, do: "bg-green-600", else: "bg-red-600")
                        ]}
                        style={"width: #{abs(value) * 100}%; max-width: 100%"}
                      >
                      </div>
                    </div>
                    <span class="w-16 text-right font-mono text-xs">
                      {value} (w:{weight})
                    </span>
                  </div>
                <% end %>
              </div>
              <button
                phx-click="clear-decision"
                class="text-xs text-stone-500 hover:text-stone-300"
              >
                Clear
              </button>
            </div>
          <% else %>
            <p class="text-stone-500 text-sm">
              Click "inspect" on a social decision event to see the factor breakdown.
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Components

  defp bar(assigns) do
    color_class =
      case assigns.color do
        "red" -> "bg-red-500"
        "green" -> "bg-green-500"
        "emerald" -> "bg-emerald-500"
        _ -> "bg-blue-500"
      end

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <div class="flex items-center gap-2 text-xs">
      <span class="w-14 text-stone-400">{@label}</span>
      <div class="flex-1 bg-stone-700 rounded h-2">
        <div class={[@color_class, "h-full rounded"]} style={"width: #{@value * 100}%"}></div>
      </div>
      <span class="w-8 text-right font-mono">{trunc(@value * 100)}%</span>
    </div>
    """
  end

  # Helpers

  defp event_color(entry) do
    case Map.get(entry, :type) do
      :person_try_eat -> "text-orange-300"
      :death -> "text-red-600 font-bold"
      t when t in [:starvation, :collapse] -> "text-red-400"
      t when t in [:crop_plant, :crop_growth_check, :crop_ready] -> "text-emerald-300"
      t when t in [:plant_begin, :plant_complete] -> "text-lime-300"
      t when t in [:harvest_begin, :harvest_complete] -> "text-yellow-300"
      t when t in [:request_work, :evaluate_request, :request_accepted, :request_refused] -> "text-blue-300"
      :daily_dawn -> "text-amber-200"
      _ -> "text-stone-300"
    end
  end

  defp event_system(entry) do
    case Map.get(entry, :system) do
      :consumption -> "EAT"
      :agriculture -> "FARM"
      :labor -> "WORK"
      :social -> "SOC"
      _ -> event_type_short(entry.type)
    end
  end

  defp event_type_short(:daily_dawn), do: "DAY"
  defp event_type_short(:error), do: "ERR"
  defp event_type_short(_), do: "SIM"

  defp system_badge(entry) do
    case Map.get(entry, :system) do
      :consumption -> "text-orange-500"
      :agriculture -> "text-emerald-500"
      :labor -> "text-yellow-500"
      :social -> "text-blue-500"
      _ -> "text-stone-500"
    end
  end

  defp parcel_state_color(:fallow), do: "text-stone-400"
  defp parcel_state_color(:planting), do: "text-lime-400"
  defp parcel_state_color(:planted), do: "text-green-400"
  defp parcel_state_color(:growing), do: "text-emerald-400"
  defp parcel_state_color(:ready), do: "text-amber-400"
  defp parcel_state_color(:harvesting), do: "text-yellow-400"
  defp parcel_state_color(_), do: "text-stone-400"

  defp task_label(%{type: :planting, parcel_id: pid}), do: "Planting #{pid}"
  defp task_label(%{type: :harvesting, parcel_id: pid}), do: "Harvesting #{pid}"
  defp task_label(%{type: type}), do: "#{type}"
  defp task_label(_), do: "Working"

  defp decision_index(event_log, entry) do
    event_log
    |> Enum.filter(&Map.has_key?(&1, :decision))
    |> Enum.find_index(&(&1 == entry))
    |> Kernel.||(0)
  end
end
