defmodule AshAgentUi.Observe.TelemetryTest do
  use ExUnit.Case, async: false

  alias AshAgentUi.Observe
  alias Phoenix.PubSub

  setup do
    Observe.clear()
    :ok
  end

  test "converts telemetry spans into runs" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :call
    }

    :telemetry.execute(
      [:ash_agent, :call, :start],
      %{system_time: System.system_time()},
      metadata
    )

    :telemetry.execute(
      [
        :ash_agent,
        :iteration,
        :start
      ],
      %{},
      %{iteration: 1}
    )

    stop_metadata = %{
      telemetry_span_context: context,
      status: :ok,
      usage: %{total_tokens: 12, input_tokens: 5, output_tokens: 7},
      response: %{
        id: "resp-1",
        model: "model-x",
        finish_reason: :stop,
        provider_meta: %{
          http_context: %{
            url: "https://api.example.com",
            method: "post",
            status: 200,
            req_headers: %{"authorization" => "[REDACTED]"},
            resp_headers: %{"x-request-id" => "req-123"}
          }
        }
      }
    }

    :telemetry.execute(
      [:ash_agent, :call, :stop],
      %{duration: 100_000},
      Map.merge(metadata, stop_metadata)
    )

    {:ok, [run | _]} = Observe.list_runs()
    assert run.status == :ok
    assert run.usage[:total_tokens] == 12
    assert run.response_id == "resp-1"
    assert run.response_model == "model-x"
    assert run.finish_reason == :stop
    assert run.http[:status] == 200
    assert run.http[:method] == "post"
    assert run.http[:url] =~ "api.example.com"
    assert is_map(run.provider_meta)
    assert length(run.events) == 1
  end

  test "tracks tool events" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :call
    }

    :telemetry.execute(
      [:ash_agent, :call, :start],
      %{system_time: System.system_time()},
      metadata
    )

    :telemetry.execute(
      [:ash_agent, :tool_call, :start],
      %{},
      %{tool_id: "tool-1", tool_name: :fetch_customer, arguments: %{}}
    )

    :telemetry.execute(
      [:ash_agent, :tool_call, :complete],
      %{},
      %{tool_id: "tool-1", tool_name: :fetch_customer, status: :success, result: %{id: 1}}
    )

    :telemetry.execute(
      [:ash_agent, :call, :stop],
      %{duration: 10_000},
      Map.merge(metadata, %{status: :ok})
    )

    {:ok, [run | _]} = Observe.list_runs()
    assert Enum.any?(run.events, &(&1.type == :tool_start))
    assert Enum.any?(run.events, &(&1.type == :tool_complete))
  end

  test "records token warnings and hook lifecycle events" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :call
    }

    :telemetry.execute(
      [:ash_agent, :call, :start],
      %{system_time: System.system_time()},
      metadata
    )

    :telemetry.execute(
      [:ash_agent, :token_limit_warning],
      %{cumulative_tokens: 900},
      %{limit: 1000, threshold_percent: 90, cumulative_tokens: 900}
    )

    :telemetry.execute(
      [:ash_agent, :hook, :start],
      %{},
      %{hook_name: :on_iteration_start}
    )

    :telemetry.execute(
      [:ash_agent, :hook, :stop],
      %{duration: 1000},
      %{hook_name: :on_iteration_start}
    )

    :telemetry.execute(
      [:ash_agent, :call, :stop],
      %{duration: 20_000},
      Map.merge(metadata, %{status: :ok})
    )

    {:ok, [run | _]} = Observe.list_runs()

    assert Enum.any?(run.events, &(&1.type == :token_limit_warning))
    assert Enum.any?(run.events, &(&1.type == :hook_start))
    assert Enum.any?(run.events, &(&1.type == :hook_stop))
  end

  test "records progressive disclosure events and broadcasts run events" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :call
    }

    PubSub.subscribe(AshAgentUi.PubSub, "ash_agent_ui:runs")

    :telemetry.execute(
      [:ash_agent, :call, :start],
      %{system_time: System.system_time()},
      metadata
    )

    assert_receive {:run_started, run}, 1_000

    run_id = run.id

    PubSub.subscribe(AshAgentUi.PubSub, "ash_agent_ui:runs:#{run_id}")

    :telemetry.execute(
      [:ash_agent, :progressive_disclosure, :token_based],
      %{budget: 1000},
      %{budget: 1000, threshold: 0.8}
    )

    assert_receive {:run_event, ^run_id, %{type: :progressive_token_based} = event}, 1_000
    assert event.metadata[:budget] == 1000
    assert event.metadata[:threshold] == 0.8

    :telemetry.execute(
      [:ash_agent, :call, :stop],
      %{duration: 10_000},
      Map.merge(metadata, %{status: :ok})
    )

    {:ok, [finished | _]} = Observe.list_runs()
    assert Enum.any?(finished.events, &(&1.type == :progressive_token_based))
  end

  test "stream summary persists events even after stop" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :stream
    }

    :telemetry.execute([:ash_agent, :stream, :start], %{}, metadata)

    :telemetry.execute(
      [:ash_agent, :stream, :stop],
      %{duration: 30_000},
      Map.merge(metadata, %{status: :ok, usage: %{total_tokens: 24}})
    )

    :telemetry.execute(
      [:ash_agent, :stream, :summary],
      %{},
      Map.merge(metadata, %{status: :ok})
    )

    {:ok, [run | _]} = Observe.list_runs()
    assert Enum.any?(run.events, &(&1.type == :call_summary))
  end

  test "stream chunk and llm response events are recorded" do
    context = make_ref()

    metadata = %{
      telemetry_span_context: context,
      agent: Demo.Agent,
      provider: :req_llm,
      client: "claude",
      type: :stream
    }

    :telemetry.execute([:ash_agent, :stream, :start], %{}, metadata)

    :telemetry.execute(
      [:ash_agent, :stream, :chunk],
      %{index: 0},
      Map.merge(metadata, %{chunk: %{message: "hi"}})
    )

    :telemetry.execute(
      [:ash_agent, :llm, :response],
      %{},
      Map.merge(metadata, %{status: :ok, response: %{id: "resp-1"}})
    )

    :telemetry.execute(
      [:ash_agent, :stream, :stop],
      %{duration: 10_000},
      Map.merge(metadata, %{status: :ok})
    )

    :telemetry.execute(
      [:ash_agent, :stream, :summary],
      %{},
      Map.merge(metadata, %{status: :ok})
    )

    {:ok, [run | _]} = Observe.list_runs()
    assert Enum.any?(run.events, &(&1.type == :chunk && &1.metadata[:chunk] == "hi"))
    assert Enum.any?(run.events, &(&1.type == :llm_response))
  end
end
