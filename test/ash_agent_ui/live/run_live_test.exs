defmodule AshAgentUi.RunLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias AshAgentUi.Observe
  alias AshAgentUi.RunLive
  alias Phoenix.LiveView.Socket

  setup do
    Observe.clear()

    {:ok, run} =
      Observe.start_run(%{
        id: "detail-run",
        agent: Demo.Agent,
        provider: :req_llm,
        client: "claude",
        type: :call
      })

    {:ok, run} =
      Observe.update_run(run.id, %{
        status: :ok,
        usage: %{total_tokens: 10, input_tokens: 4, output_tokens: 6},
        duration_ms: 120,
        input: %{message: "hello"},
        result: %{reply: "hi"},
        provider_meta: %{request_id: "req-1"},
        http: %{status: 200, method: "post", url: "https://example"},
        error: %{reason: :none},
        events: [
          %{
            id: "evt-prog",
            event: [:ash_agent, :progressive_disclosure, :token_based],
            type: :progressive_token_based,
            metadata: %{budget: 1000, threshold: 0.8},
            measurements: %{},
            timestamp: DateTime.utc_now()
          }
        ]
      })

    {:ok, run: run}
  end

  test "mount assigns base metadata and timeline updates", %{run: run} do
    socket = %Socket{
      assigns: %{__changed__: %{}, flash: %{}, live_action: nil},
      private: %{ash_agent_ui_base_path: "/ash-agent-ui"}
    }

    {:ok, socket} =
      RunLive.mount(%{"id" => run.id}, %{"ash_agent_ui_base_path" => "/ash-agent-ui"}, socket)

    assert socket.assigns.run.id == run.id
    assert socket.assigns.base_path == "/ash-agent-ui"

    event = %{
      id: "evt-test",
      event: [:ash_agent, :token_limit_warning],
      type: :token_limit_warning,
      metadata: %{limit: 1000, cumulative_tokens: 900},
      measurements: %{},
      timestamp: DateTime.utc_now()
    }

    {:noreply, socket} = RunLive.handle_info({:run_event, run.id, event}, socket)
    assert Enum.any?(socket.assigns.events, &(&1.type == :token_limit_warning))

    rendered =
      socket.assigns
      |> RunLive.render()
      |> rendered_to_string()

    assert rendered =~ "Payloads"
    assert rendered =~ "Metadata"
    assert rendered =~ "Error"
    assert rendered =~ "Progressive disclosure (token based)"
    assert rendered =~ "Budget 1000"
  end
end
