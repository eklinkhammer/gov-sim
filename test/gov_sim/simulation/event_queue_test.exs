defmodule GovSim.Simulation.EventQueueTest do
  use ExUnit.Case, async: true

  alias GovSim.Simulation.EventQueue
  alias GovSim.Events.Event

  test "new creates empty queue" do
    q = EventQueue.new()
    assert EventQueue.empty?(q)
    assert EventQueue.size(q) == 0
  end

  test "push maintains time ordering" do
    q =
      EventQueue.new()
      |> EventQueue.push(Event.new(100, :b))
      |> EventQueue.push(Event.new(50, :a))
      |> EventQueue.push(Event.new(200, :c))

    {:ok, e1, q} = EventQueue.pop(q)
    {:ok, e2, q} = EventQueue.pop(q)
    {:ok, e3, _q} = EventQueue.pop(q)

    assert e1.type == :a
    assert e2.type == :b
    assert e3.type == :c
  end

  test "pop returns :empty for empty queue" do
    assert EventQueue.pop(EventQueue.new()) == :empty
  end

  test "push_many adds multiple events" do
    events = [Event.new(300, :c), Event.new(100, :a), Event.new(200, :b)]
    q = EventQueue.push_many(EventQueue.new(), events)
    assert EventQueue.size(q) == 3

    {:ok, first, _} = EventQueue.pop(q)
    assert first.type == :a
  end

  test "peek shows next without removing" do
    q = EventQueue.push(EventQueue.new(), Event.new(100, :a))
    {:ok, event} = EventQueue.peek(q)
    assert event.type == :a
    assert EventQueue.size(q) == 1
  end
end
