defmodule AshAgentUi.Observe.StoreTest do
  use ExUnit.Case, async: false

  alias AshAgentUi.Observe

  setup do
    Observe.clear()
    :ok
  end

  test "records runs and lists newest first" do
    {:ok, run_a} =
      Observe.start_run(%{
        id: "run-a",
        agent: Demo.Agent,
        provider: :req_llm,
        client: "claude",
        type: :call
      })

    Process.sleep(1)

    {:ok, run_b} =
      Observe.start_run(%{
        id: "run-b",
        agent: Demo.Agent,
        provider: :req_llm,
        client: "claude",
        type: :call
      })

    {:ok, [first, second | _]} = Observe.list_runs()
    assert first.id == run_b.id
    assert second.id == run_a.id

    assert run_a.started_at
    assert run_b.started_at
  end

  test "updates run metadata" do
    {:ok, run} =
      Observe.start_run(%{
        id: "run-1",
        agent: Demo.Agent,
        provider: :req_llm,
        client: "claude",
        type: :call
      })

    {:ok, updated} = Observe.update_run(run.id, %{status: :ok, duration_ms: 120})
    assert updated.status == :ok
    assert updated.duration_ms == 120

    {:ok, [fetched | _]} = Observe.list_runs()
    assert fetched.id == run.id
    assert fetched.status == :ok
  end

  test "appends events to run timeline" do
    {:ok, run} =
      Observe.start_run(%{
        id: "run-events",
        agent: Demo.Agent,
        provider: :req_llm,
        client: "claude",
        type: :call
      })

    event = %{type: :iteration_start, iteration: 1, timestamp: DateTime.utc_now()}
    {:ok, updated} = Observe.append_event(run.id, event)

    assert length(updated.events) == 1
    assert hd(updated.events)[:type] == :iteration_start
  end
end
