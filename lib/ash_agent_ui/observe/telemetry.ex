defmodule AshAgentUi.Observe.Telemetry do
  use GenServer

  alias AshAgentUi.Observe

  @call_events [
    [:ash_agent, :call, :start],
    [:ash_agent, :call, :stop],
    [:ash_agent, :call, :exception]
  ]

  @stream_events [
    [:ash_agent, :stream, :start],
    [:ash_agent, :stream, :stop],
    [:ash_agent, :stream, :exception]
  ]

  @iteration_event [:ash_agent, :iteration, :start]
  @iteration_stop_event [:ash_agent, :iteration, :stop]
  @tool_start_event [:ash_agent, :tool_call, :start]
  @tool_complete_event [:ash_agent, :tool_call, :complete]
  @tool_decision_event [:ash_agent, :tool_call, :decision]
  @tool_retry_event [:ash_agent, :tool_call, :retry]
  @tool_error_event [:ash_agent, :tool_call, :error]
  @token_warning_event [:ash_agent, :token_limit_warning]
  @token_progress_event [:ash_agent, :token_limit_progress]
  @prompt_rendered_event [:ash_agent, :prompt, :rendered]
  @llm_request_event [:ash_agent, :llm, :request]
  @llm_response_event [:ash_agent, :llm, :response]
  @call_summary_event [:ash_agent, :call, :summary]
  @stream_summary_event [:ash_agent, :stream, :summary]
  @annotation_event [:ash_agent, :annotation]

  @hook_events [
    [:ash_agent, :hook, :start],
    [:ash_agent, :hook, :stop],
    [:ash_agent, :hook, :error]
  ]

  @progressive_events [
    [:ash_agent, :progressive_disclosure, :process_results],
    [:ash_agent, :progressive_disclosure, :sliding_window],
    [:ash_agent, :progressive_disclosure, :token_based]
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    span_table = :ets.new(:ash_agent_ui_span_index, [:set, :public, read_concurrency: true])
    pid_table = :ets.new(:ash_agent_ui_pid_index, [:set, :public, write_concurrency: true])

    config = %{
      span_table: span_table,
      pid_table: pid_table,
      pubsub: Keyword.get(opts, :pubsub, AshAgentUi.PubSub)
    }

    handler_ids = attach_handlers(config)

    {:ok, Map.put(config, :handler_ids, handler_ids)}
  end

  @impl true
  def terminate(_reason, %{handler_ids: ids} = state) do
    Enum.each(ids, &:telemetry.detach/1)
    :ets.delete(state.span_table)
    :ets.delete(state.pid_table)
    :ok
  end

  def handle_event(event, measurements, metadata, config)

  def handle_event([:ash_agent, kind, :start], _measurements, metadata, config)
      when kind in [:call, :stream] do
    run_type = Map.get(metadata, :type, kind)
    run_id = generate_run_id(run_type)

    record = %{
      id: run_id,
      type: run_type,
      agent: Map.get(metadata, :agent),
      provider: Map.get(metadata, :provider),
      profile: Map.get(metadata, :profile),
      client: Map.get(metadata, :client),
      status: :running,
      started_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      input: Map.get(metadata, :input)
    }

    {:ok, run} = Observe.start_run(record)
    track_span(config.span_table, metadata[:telemetry_span_context], run_id)
    push_pid(config.pid_table, self(), run_id)
    broadcast_run(:run_started, run, config.pubsub)
  end

  def handle_event([:ash_agent, kind, :stop], measurements, metadata, config)
      when kind in [:call, :stream] do
    case lookup_run_id(metadata[:telemetry_span_context], config) do
      {:ok, run_id} ->
        attrs = build_run_update_attrs(measurements, metadata)
        {:ok, run} = Observe.update_run(run_id, attrs)
        broadcast_run(:run_updated, run, config.pubsub)

      _ ->
        :ok
    end
  end

  def handle_event([:ash_agent, _kind, :exception], _measurements, metadata, config) do
    case lookup_run_id(metadata[:telemetry_span_context], config) do
      {:ok, run_id} ->
        attrs =
          build_run_update_attrs(%{}, metadata, %{
            status: :error,
            error:
              Map.get(metadata, :error) ||
                %{
                  kind: Map.get(metadata, :kind),
                  reason: Map.get(metadata, :reason),
                  stacktrace: Map.get(metadata, :stacktrace)
                }
          })

        {:ok, run} = Observe.update_run(run_id, attrs)
        pop_pid(config.pid_table, self())
        untrack_span(config.span_table, metadata[:telemetry_span_context])
        broadcast_run(:run_updated, run, config.pubsub)

      _ ->
        :ok
    end
  end

  def handle_event(@iteration_event, _measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@iteration_event, %{}, %{
          iteration: Map.get(metadata, :iteration)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@iteration_stop_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@iteration_stop_event, measurements, %{
          iteration: Map.get(metadata, :iteration),
          status: Map.get(metadata, :status)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@tool_start_event, _measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@tool_start_event, %{}, %{
          iteration: Map.get(metadata, :iteration),
          tool_id: Map.get(metadata, :tool_id),
          tool_name: Map.get(metadata, :tool_name),
          arguments: Map.get(metadata, :arguments)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@tool_complete_event, _measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@tool_complete_event, %{}, %{
          iteration: Map.get(metadata, :iteration),
          tool_id: Map.get(metadata, :tool_id),
          tool_name: Map.get(metadata, :tool_name),
          status: Map.get(metadata, :status),
          result: Map.get(metadata, :result),
          error: Map.get(metadata, :error)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@tool_decision_event, _measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@tool_decision_event, %{}, %{
          iteration: Map.get(metadata, :iteration),
          tool_name: Map.get(metadata, :tool_name),
          considered: Map.get(metadata, :considered_tools)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@tool_retry_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@tool_retry_event, measurements, %{
          iteration: Map.get(metadata, :iteration),
          tool_id: Map.get(metadata, :tool_id),
          tool_name: Map.get(metadata, :tool_name),
          error: Map.get(metadata, :error)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@tool_error_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@tool_error_event, measurements, %{
          iteration: Map.get(metadata, :iteration),
          tool_id: Map.get(metadata, :tool_id),
          tool_name: Map.get(metadata, :tool_name),
          error: Map.get(metadata, :error)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@token_warning_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@token_warning_event, measurements, %{
          limit: Map.get(metadata, :limit),
          threshold_percent: Map.get(metadata, :threshold_percent),
          cumulative_tokens: Map.get(metadata, :cumulative_tokens)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@token_progress_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@token_progress_event, measurements, %{
          threshold_percent: Map.get(metadata, :threshold_percent),
          cumulative_tokens: Map.get(metadata, :cumulative_tokens)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event([:ash_agent, :hook, phase] = event_name, measurements, metadata, config)
      when phase in [:start, :stop, :error] do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(event_name, measurements, %{
          hook_name: Map.get(metadata, :hook_name),
          error: Map.get(metadata, :error)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(
        [:ash_agent, :progressive_disclosure, stage] = event_name,
        measurements,
        metadata,
        config
      )
      when stage in [:process_results, :sliding_window, :token_based] do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      meta_payload =
        case stage do
          :process_results ->
            %{options: Map.get(metadata, :options)}

          :sliding_window ->
            %{window_size: Map.get(metadata, :window_size)}

          :token_based ->
            %{
              budget: Map.get(metadata, :budget),
              threshold: Map.get(metadata, :threshold)
            }
        end

      event = build_event(event_name, measurements, meta_payload)
      persist_event(run_id, event, config)
    end
  end

  def handle_event(@prompt_rendered_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@prompt_rendered_event, measurements, %{
          prompt_preview: Map.get(metadata, :prompt_preview)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@llm_request_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@llm_request_event, measurements, %{
          iteration: Map.get(metadata, :iteration)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event(@llm_response_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event =
        build_event(@llm_response_event, measurements, %{
          iteration: Map.get(metadata, :iteration),
          status: Map.get(metadata, :status)
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event([:ash_agent, :stream, :chunk], measurements, metadata, config) do
    run_id_result =
      lookup_run_id(metadata[:telemetry_span_context], config)
      |> fallback_pid_lookup(config)

    with {:ok, run_id} <- run_id_result do
      event =
        build_event([:ash_agent, :stream, :chunk], measurements, %{
          chunk: chunk_text(Map.get(metadata, :chunk))
        })

      persist_event(run_id, event, config)
    end
  end

  def handle_event([:ash_agent, kind, :summary] = event_name, measurements, metadata, config)
      when kind in [:call, :stream] do
    with {:ok, run_id} <-
           lookup_run_id(metadata[:telemetry_span_context], config)
           |> fallback_pid_lookup(config),
         {:ok, run} <-
           persist_event(run_id, build_event(event_name, measurements, metadata), config) do
      broadcast_run(:run_updated, run, config.pubsub)
      pop_pid(config.pid_table, self())
      untrack_span(config.span_table, metadata[:telemetry_span_context])
    else
      _ -> :ok
    end
  end

  def handle_event(@annotation_event, measurements, metadata, config) do
    with {:ok, run_id} <- lookup_pid(self(), config) do
      event = build_event(@annotation_event, measurements, metadata)
      persist_event(run_id, event, config)
    end
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  defp persist_event(run_id, event, config) do
    case Observe.append_event(run_id, event) do
      {:ok, run} ->
        broadcast_event(run_id, event, config.pubsub)
        {:ok, run}

      error ->
        error
    end
  end

  defp build_event(name, measurements, metadata) do
    %{
      event: name,
      type: infer_event_type(name),
      metadata: clean_metadata(metadata),
      measurements: clean_measurements(measurements),
      timestamp: DateTime.utc_now()
    }
  end

  defp clean_metadata(metadata) when is_map(metadata) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      Map.put(acc, key, clean_term(value))
    end)
  end

  defp clean_metadata(_), do: %{}

  defp clean_measurements(measurements) when is_map(measurements) do
    Enum.into(measurements, %{}, fn {key, value} ->
      {key, clean_measurement_value(value)}
    end)
  end

  defp clean_measurements(_), do: %{}
  defp clean_measurement_value(%{} = map), do: clean_metadata(map)
  defp clean_measurement_value(value), do: value

  defp infer_event_type([:ash_agent, :iteration, :start]), do: :iteration_start
  defp infer_event_type([:ash_agent, :iteration, :stop]), do: :iteration_stop
  defp infer_event_type([:ash_agent, :tool_call, :start]), do: :tool_start
  defp infer_event_type([:ash_agent, :tool_call, :complete]), do: :tool_complete
  defp infer_event_type([:ash_agent, :tool_call, :decision]), do: :tool_decision
  defp infer_event_type([:ash_agent, :tool_call, :retry]), do: :tool_retry
  defp infer_event_type([:ash_agent, :tool_call, :error]), do: :tool_error
  defp infer_event_type([:ash_agent, :token_limit_warning]), do: :token_limit_warning
  defp infer_event_type([:ash_agent, :token_limit_progress]), do: :token_limit_progress
  defp infer_event_type([:ash_agent, :hook, :start]), do: :hook_start
  defp infer_event_type([:ash_agent, :hook, :stop]), do: :hook_stop
  defp infer_event_type([:ash_agent, :hook, :error]), do: :hook_error
  defp infer_event_type([:ash_agent, :prompt, :rendered]), do: :prompt_rendered
  defp infer_event_type([:ash_agent, :llm, :request]), do: :llm_request
  defp infer_event_type([:ash_agent, :llm, :response]), do: :llm_response
  defp infer_event_type([:ash_agent, :stream, :chunk]), do: :chunk
  defp infer_event_type([:ash_agent, :call, :summary]), do: :call_summary
  defp infer_event_type([:ash_agent, :stream, :summary]), do: :call_summary
  defp infer_event_type([:ash_agent, :annotation]), do: :annotation

  defp infer_event_type([:ash_agent, :progressive_disclosure, stage]) do
    :"progressive_#{stage}"
  end

  defp infer_event_type(event) when is_list(event) do
    List.last(event)
  end

  defp fallback_pid_lookup({:ok, _run_id} = ok, _config), do: ok
  defp fallback_pid_lookup(_error, config), do: lookup_pid(self(), config)

  defp chunk_text(%{message: msg}) when is_binary(msg), do: msg
  defp chunk_text(%{delta: msg}) when is_binary(msg), do: msg
  defp chunk_text(msg) when is_binary(msg), do: msg
  defp chunk_text(_), do: nil

  defp build_run_update_attrs(measurements, metadata, overrides \\ %{}) do
    response = Map.get(metadata, :response)
    provider_meta = provider_meta_from_response(response)

    base = %{
      status: Map.get(metadata, :status, :ok),
      profile: Map.get(metadata, :profile),
      completed_at: DateTime.utc_now(),
      duration_ms: convert_duration(measurements[:duration]),
      usage: Map.get(metadata, :usage),
      result: Map.get(metadata, :result),
      error: Map.get(metadata, :error),
      response_id: response_field(response, :id),
      response_model: response_field(response, :model),
      finish_reason: response_field(response, :finish_reason),
      provider_meta: provider_meta,
      http: build_http_snapshot(metadata, provider_meta)
    }

    Map.merge(base, overrides, fn _key, _old, new -> new end)
  end

  defp provider_meta_from_response(nil), do: nil

  defp provider_meta_from_response(response) do
    response
    |> Map.get(:provider_meta) ||
      Map.get(response, "provider_meta")
      |> clean_term()
  end

  defp response_field(nil, _key), do: nil
  defp response_field(response, key), do: Map.get(response, key)

  defp build_http_snapshot(metadata, provider_meta) do
    provider_meta
    |> provider_http_context()
    |> clean_term()
    |> snapshot_from_http_context(metadata)
  end

  defp provider_http_context(nil), do: nil

  defp provider_http_context(meta),
    do: fetch_field(meta, :http_context) || fetch_field(meta, :http)

  defp snapshot_from_http_context(%{} = http_context, metadata) do
    %{
      url: fetch_field(http_context, :url),
      method: fetch_field(http_context, :method),
      status: fetch_field(http_context, :status) || Map.get(metadata, :status),
      request_headers: fetch_field(http_context, :req_headers),
      response_headers: fetch_field(http_context, :resp_headers)
    }
    |> prune_empty_snapshot()
  end

  defp snapshot_from_http_context(_http_context, %{status: status, headers: headers} = metadata) do
    if status || headers do
      %{
        status: Map.get(metadata, :status),
        response_headers: metadata[:headers]
      }
      |> prune_empty_snapshot()
    else
      nil
    end
  end

  defp snapshot_from_http_context(_http_context, _metadata), do: nil

  defp prune_empty_snapshot(snapshot) do
    snapshot
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == %{} end)
    |> Map.new()
    |> case do
      %{} = map when map_size(map) == 0 -> nil
      map -> map
    end
  end

  defp fetch_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp fetch_field(_, _), do: nil

  defp clean_term(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, key, clean_term(value))
    end)
  end

  defp clean_term(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, key, clean_term(value))
    end)
  end

  defp clean_term(list) when is_list(list), do: Enum.map(list, &clean_term/1)
  defp clean_term(value), do: value

  defp attach_handlers(config) do
    call_id = "ash_agent_ui-call"
    stream_id = "ash_agent_ui-stream"
    iter_id = "ash_agent_ui-iteration"
    iter_stop_id = "ash_agent_ui-iteration-stop"
    tool_start_id = "ash_agent_ui-tool-start"
    tool_complete_id = "ash_agent_ui-tool-complete"
    tool_decision_id = "ash_agent_ui-tool-decision"
    tool_retry_id = "ash_agent_ui-tool-retry"
    tool_error_id = "ash_agent_ui-tool-error"
    token_id = "ash_agent_ui-token-warning"
    token_progress_id = "ash_agent_ui-token-progress"
    hook_id = "ash_agent_ui-hook"
    progressive_id = "ash_agent_ui-progressive"
    prompt_id = "ash_agent_ui-prompt"
    llm_request_id = "ash_agent_ui-llm-request"
    llm_response_id = "ash_agent_ui-llm-response"
    stream_chunk_id = "ash_agent_ui-stream-chunk"
    call_summary_id = "ash_agent_ui-call-summary"
    stream_summary_id = "ash_agent_ui-stream-summary"
    annotation_id = "ash_agent_ui-annotation"

    :telemetry.attach_many(call_id, @call_events, &__MODULE__.handle_event/4, config)
    :telemetry.attach_many(stream_id, @stream_events, &__MODULE__.handle_event/4, config)
    :telemetry.attach(iter_id, @iteration_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(iter_stop_id, @iteration_stop_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(tool_start_id, @tool_start_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(tool_complete_id, @tool_complete_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(tool_decision_id, @tool_decision_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(tool_retry_id, @tool_retry_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(tool_error_id, @tool_error_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(token_id, @token_warning_event, &__MODULE__.handle_event/4, config)

    :telemetry.attach(
      token_progress_id,
      @token_progress_event,
      &__MODULE__.handle_event/4,
      config
    )

    :telemetry.attach_many(hook_id, @hook_events, &__MODULE__.handle_event/4, config)

    :telemetry.attach_many(
      progressive_id,
      @progressive_events,
      &__MODULE__.handle_event/4,
      config
    )

    :telemetry.attach(prompt_id, @prompt_rendered_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(llm_request_id, @llm_request_event, &__MODULE__.handle_event/4, config)
    :telemetry.attach(llm_response_id, @llm_response_event, &__MODULE__.handle_event/4, config)

    :telemetry.attach(
      stream_chunk_id,
      [:ash_agent, :stream, :chunk],
      &__MODULE__.handle_event/4,
      config
    )

    :telemetry.attach(call_summary_id, @call_summary_event, &__MODULE__.handle_event/4, config)

    :telemetry.attach(
      stream_summary_id,
      @stream_summary_event,
      &__MODULE__.handle_event/4,
      config
    )

    :telemetry.attach(annotation_id, @annotation_event, &__MODULE__.handle_event/4, config)

    [
      call_id,
      stream_id,
      iter_id,
      iter_stop_id,
      tool_start_id,
      tool_complete_id,
      tool_decision_id,
      tool_retry_id,
      tool_error_id,
      token_id,
      token_progress_id,
      hook_id,
      progressive_id,
      prompt_id,
      llm_request_id,
      llm_response_id,
      call_summary_id,
      stream_summary_id,
      annotation_id
    ]
  end

  defp generate_run_id(kind) do
    suffix = System.unique_integer([:positive])
    "#{kind}-#{suffix}"
  end

  defp convert_duration(nil), do: nil
  defp convert_duration(value), do: System.convert_time_unit(value, :native, :millisecond)

  defp track_span(table, nil, _run_id), do: table

  defp track_span(table, context, run_id) do
    :ets.insert(table, {context, run_id})
    table
  end

  defp untrack_span(table, nil), do: table

  defp untrack_span(table, context) do
    :ets.delete(table, context)
    table
  end

  defp lookup_run_id(nil, config), do: lookup_pid(self(), config)

  defp lookup_run_id(context, %{span_table: table} = config) do
    case :ets.lookup(table, context) do
      [{^context, run_id}] -> {:ok, run_id}
      _ -> lookup_pid(self(), config)
    end
  end

  defp lookup_pid(pid, %{pid_table: table}) do
    case :ets.lookup(table, pid) do
      [{^pid, [run_id | _]}] -> {:ok, run_id}
      _ -> :error
    end
  end

  defp push_pid(table, pid, run_id) do
    case :ets.lookup(table, pid) do
      [] -> :ets.insert(table, {pid, [run_id]})
      [{^pid, stack}] -> :ets.insert(table, {pid, [run_id | stack]})
    end
  end

  defp pop_pid(table, pid) do
    case :ets.lookup(table, pid) do
      [] ->
        :ok

      [{^pid, [_ | rest]}] ->
        if rest == [] do
          :ets.delete(table, pid)
        else
          :ets.insert(table, {pid, rest})
        end
    end
  end

  defp broadcast_run(event, run, pubsub) do
    Phoenix.PubSub.broadcast(pubsub, "ash_agent_ui:runs", {event, run})

    if run_id = Map.get(run, :id) do
      Phoenix.PubSub.broadcast(
        pubsub,
        "ash_agent_ui:runs:" <> to_string(run_id),
        {:run_snapshot, run}
      )
    end
  end

  defp broadcast_event(run_id, event, pubsub) do
    Phoenix.PubSub.broadcast(pubsub, "ash_agent_ui:runs:" <> run_id, {:run_event, run_id, event})
  end
end
