defmodule GovSim.Events.Handlers.Social do
  @moduledoc """
  Handlers for request_work, evaluate_request, request_accepted, request_refused.
  Social primitives: father asking child to harvest is structurally identical
  to king summoning vassal.
  """

  @behaviour GovSim.Events.Handler

  alias GovSim.Events.Event
  alias GovSim.World.World
  alias GovSim.Systems.Decision

  @impl true
  def handle(%Event{type: :request_work, time: time, entity_id: requester_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    target_id = payload.target_id
    requester = World.get_person(world, requester_id)
    target = World.get_person(world, target_id)

    if requester == nil or target == nil do
      {world, []}
    else
      log_entry = %{
        time: time,
        type: :request_work,
        system: :social,
        message: "#{requester.name} asks #{target.name} to help with #{payload.task}."
      }

      eval_event =
        Event.new(time + 5, :evaluate_request, target_id, %{
          requester_id: requester_id,
          parcel_id: payload.parcel_id,
          task: payload.task
        })

      {World.log_event(world, log_entry), [eval_event]}
    end
  end

  def handle(%Event{type: :evaluate_request, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    requester_id = payload.requester_id
    person = World.get_person(world, person_id)
    requester = World.get_person(world, requester_id)

    if person == nil or requester == nil do
      {world, []}
    else
      household = World.get_household(world, person.household_id)
      is_head = household && household.head_id == requester_id

      relationship =
        case Map.get(person.relationships, requester_id) do
          nil -> :stranger
          rel -> rel
        end

      obedience = Map.get(person.personality, :obedience, 0.5)

      params = %{
        requester_is_head: is_head,
        relationship: relationship,
        energy: person.energy,
        obedience: obedience
      }

      {decision, score, factors} = Decision.evaluate(params)

      log_entry = %{
        time: time,
        type: :evaluate_request,
        system: :social,
        message: "#{person.name} considers request (score: #{score}): #{decision}.",
        decision: %{
          person: person.name,
          decision: decision,
          score: score,
          factors: factors
        }
      }

      world = World.log_event(world, log_entry)

      case decision do
        :accept ->
          evt =
            Event.new(time + 2, :request_accepted, person_id, %{
              requester_id: requester_id,
              parcel_id: payload.parcel_id,
              task: payload.task,
              decision_factors: factors,
              decision_score: score
            })

          {world, [evt]}

        :refuse ->
          evt =
            Event.new(time + 2, :request_refused, person_id, %{
              requester_id: requester_id,
              parcel_id: payload.parcel_id,
              task: payload.task,
              decision_factors: factors,
              decision_score: score
            })

          {world, [evt]}
      end
    end
  end

  def handle(%Event{type: :request_accepted, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    person = World.get_person(world, person_id)
    requester = World.get_person(world, payload.requester_id)

    if person == nil do
      {world, []}
    else
      task = Map.get(payload, :task, :harvest)

      log_entry = %{
        time: time,
        type: :request_accepted,
        system: :social,
        message: "#{person.name} agrees to help #{requester && requester.name || "someone"} with #{task}."
      }

      # Dispatch to correct work type
      begin_type = if task == :plant, do: :plant_begin, else: :harvest_begin
      work_event =
        Event.new(time + 10, begin_type, person_id, %{parcel_id: payload.parcel_id})

      {World.log_event(world, log_entry), [work_event]}
    end
  end

  def handle(%Event{type: :request_refused, time: time, entity_id: person_id, payload: payload}, world) do
    world = %{world | sim_time: time}
    person = World.get_person(world, person_id)
    requester = World.get_person(world, payload.requester_id)

    if person == nil do
      {world, []}
    else
      log_entry = %{
        time: time,
        type: :request_refused,
        system: :social,
        message: "#{person.name} refuses #{requester && requester.name || "someone"}'s request to harvest."
      }

      {World.log_event(world, log_entry), []}
    end
  end
end
