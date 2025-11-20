defmodule AshAgentUi.RunLive do
  use Phoenix.LiveView

  alias AshAgentUi.Layouts
  alias AshAgentUi.Observe
  alias AshAgentUi.Observe.Components

  @impl true
  def mount(%{"id" => id}, session, socket) do
    base_path =
      session["ash_agent_ui_base_path"] || socket.private[:ash_agent_ui_base_path] || "/"

    run = fetch_run(id)

    socket =
      socket
      |> assign(:run, run)
      |> assign(:events, run_events(run))
      |> assign(:base_path, base_path)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshAgentUi.PubSub, "ash_agent_ui:runs:#{id}")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:run_snapshot, run}, socket) do
    {:noreply, assign(socket, run: run, events: run_events(run))}
  end

  def handle_info({:run_event, _id, event}, socket) do
    {:noreply, update(socket, :events, &(&1 ++ [event]))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-10">
        <div class="relative overflow-hidden rounded-3xl border border-emerald-100/80 bg-white/90 p-8 shadow-[0_30px_90px_-60px_rgba(0,0,0,0.35)] backdrop-blur-md dark:border-white/10 dark:bg-white/5 dark:shadow-[0_30px_90px_-70px_rgba(0,0,0,0.75)] lg:p-10">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_18%_22%,rgba(16,185,129,0.14),transparent_40%),radial-gradient(circle_at_88%_0%,rgba(59,130,246,0.14),transparent_30%)]" />
          <div class="relative flex flex-wrap items-center justify-between gap-6">
            <div class="space-y-3">
              <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-emerald-700/80 dark:text-emerald-100/70">
                Run Detail
              </p>
              <h1 class="text-3xl font-semibold text-zinc-900 drop-shadow-sm dark:text-white">
                {inspect(@run.agent)}
              </h1>
              <p class="text-sm text-zinc-600 dark:text-zinc-200/80">
                Client {inspect(@run.client)} · Provider {inspect(@run.provider)} · Profile {format_profile(@run.profile)}
              </p>
              <div class="inline-flex items-center gap-2 rounded-full bg-white/80 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-800 ring-1 ring-emerald-100/80 dark:bg-white/5 dark:text-emerald-100 dark:ring-white/10">
                <span class="inline-flex h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                Live updates
              </div>
            </div>
            <div class="flex items-center gap-3">
              <Components.status_badge status={@run.status} />
              <a
                href={@base_path}
                class="inline-flex items-center gap-2 rounded-2xl border border-emerald-200/70 bg-emerald-50/80 px-3 py-2 text-sm font-semibold text-emerald-900 shadow-sm transition hover:-translate-y-[1px] hover:bg-emerald-100 dark:border-white/10 dark:bg-white/10 dark:text-emerald-100"
              >
                ← Back to overview
              </a>
            </div>
          </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <Components.stat_card label="Started" value={format_datetime(@run.started_at)} />
          <Components.stat_card label="Duration" value={format_duration(@run.duration_ms)} />
          <Components.stat_card label="Tokens" value={token_count(@run)} />
        </div>

        <div class="grid gap-4 sm:grid-cols-3">
          <Components.stat_card
            label="Input Tokens"
            value={token_breakdown(@run, :input_tokens)}
            hint="Prompt tokens"
          />
          <Components.stat_card
            label="Output Tokens"
            value={token_breakdown(@run, :output_tokens)}
            hint="Completion tokens"
          />
          <Components.stat_card
            label="Reasoning Tokens"
            value={token_breakdown(@run, :reasoning_tokens)}
            hint="Provider-reported reasoning tokens"
          />
        </div>

        <div class="grid gap-6 lg:grid-cols-2">
          <section class="rounded-2xl border border-emerald-100/70 bg-white/90 p-6 shadow-[0_20px_60px_-40px_rgba(0,0,0,0.3)] dark:border-white/10 dark:bg-white/5 dark:shadow-[0_20px_70px_-50px_rgba(0,0,0,0.75)]">
            <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
              Input
            </p>
            <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
              Arguments submitted to the agent
            </p>
            <pre class="mt-4 overflow-x-auto rounded-xl bg-zinc-900/80 p-4 text-xs text-emerald-100 ring-1 ring-black/5 dark:bg-black/30 dark:ring-white/5">{render_payload(@run.input)}</pre>
          </section>

          <section class="rounded-2xl border border-emerald-100/70 bg-white/90 p-6 shadow-[0_20px_60px_-40px_rgba(0,0,0,0.3)] dark:border-white/10 dark:bg-white/5 dark:shadow-[0_20px_70px_-50px_rgba(0,0,0,0.75)]">
            <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
              Result
            </p>
            <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
              Parsed output returned by the provider
            </p>
            <pre class="mt-4 overflow-x-auto rounded-xl bg-zinc-900/80 p-4 text-xs text-emerald-100 ring-1 ring-black/5 dark:bg-black/30 dark:ring-white/5">{render_payload(@run.result)}</pre>
          </section>
        </div>

        <%= if @run.http || @run.provider_meta do %>
          <div class="grid gap-6 lg:grid-cols-2">
            <%= if @run.http do %>
              <section class="rounded-2xl border border-emerald-100/70 bg-white/90 p-6 space-y-4 shadow-[0_20px_60px_-40px_rgba(0,0,0,0.3)] dark:border-white/10 dark:bg-white/5 dark:shadow-[0_20px_70px_-50px_rgba(0,0,0,0.75)]">
                <div>
                  <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                    HTTP metadata
                  </p>
                  <p class="text-xs text-zinc-500 dark:text-zinc-400">
                    Captured from provider telemetry
                  </p>
                </div>
                <dl class="space-y-3 text-sm">
                  <%= for {label, value} <- http_entries(@run.http) do %>
                    <div>
                      <dt class="text-xs uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                        {label}
                      </dt>
                      <dd class="font-mono text-emerald-800 break-all dark:text-emerald-100">
                        {value}
                      </dd>
                    </div>
                  <% end %>
                </dl>
              </section>
            <% end %>

            <%= if @run.provider_meta do %>
              <section class="rounded-2xl border border-emerald-100/70 bg-white/90 p-6 shadow-[0_20px_60px_-40px_rgba(0,0,0,0.3)] dark:border-white/10 dark:bg-white/5 dark:shadow-[0_20px_70px_-50px_rgba(0,0,0,0.75)]">
                <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                  Provider metadata
                </p>
                <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
                  Provider model: {@run.response_model || "--"} · Response ID: {@run.response_id ||
                    "--"} ·
                  Finish: {@run.finish_reason || "--"}
                </p>
                <pre class="mt-4 overflow-x-auto rounded-xl bg-zinc-900/70 p-4 text-xs text-emerald-100 ring-1 ring-black/5 dark:bg-black/30 dark:ring-white/5">{render_payload(@run.provider_meta)}</pre>
              </section>
            <% end %>
          </div>
        <% end %>

        <%= if @run.error do %>
          <div class="rounded-2xl border border-rose-500/50 bg-rose-500/10 p-6 shadow-[0_20px_60px_-40px_rgba(244,63,94,0.6)]">
            <p class="text-sm font-semibold uppercase tracking-wide text-rose-200">Error</p>
            <pre class="mt-3 overflow-x-auto text-xs text-rose-100">{render_payload(@run.error)}</pre>
          </div>
        <% end %>

        <div class="rounded-3xl border border-emerald-100/70 bg-white/90 shadow-[0_30px_90px_-60px_rgba(0,0,0,0.3)] dark:border-white/10 dark:bg-white/5 dark:shadow-[0_30px_90px_-70px_rgba(0,0,0,0.75)]">
          <div class="border-b border-emerald-100/60 px-6 py-4 flex items-center justify-between dark:border-white/5">
            <p class="text-sm font-semibold uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
              Timeline
            </p>
            <span class="text-xs text-zinc-500 dark:text-zinc-500">{length(@events)} events</span>
          </div>
          <%= if Enum.empty?(@events) do %>
            <p class="px-6 py-10 text-sm text-zinc-500 dark:text-zinc-400">No events captured yet.</p>
          <% else %>
            <ul class="divide-y divide-emerald-100/60 dark:divide-white/5">
              <%= for event <- @events do %>
                <li class="px-6 py-4 space-y-1">
                  <div class="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-700 ring-1 ring-emerald-200 dark:bg-white/5 dark:text-emerald-100 dark:ring-white/10">
                    <span>{event_label(event)}</span>
                  </div>
                  <p class="text-xs text-zinc-500 dark:text-zinc-400">
                    {format_datetime(event.timestamp)}
                  </p>
                  <%= if details = event_details(event) do %>
                    <p class="mt-2 text-sm text-emerald-800 dark:text-emerald-100/90">{details}</p>
                  <% end %>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp fetch_run(id) do
    case Observe.fetch_run(id) do
      {:ok, run} ->
        run

      _ ->
        %{
          id: id,
          agent: "Unknown",
          provider: nil,
          client: nil,
          status: :unknown,
          started_at: nil,
          duration_ms: nil,
          usage: nil,
          events: []
        }
    end
  end

  defp run_events(%{events: events}) when is_list(events), do: events
  defp run_events(_), do: []

  defp format_datetime(nil), do: "--"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d %H:%M:%S.%3f")
  end

  defp format_duration(nil), do: "--"
  defp format_duration(ms) when is_number(ms), do: Integer.to_string(ms) <> " ms"

  defp token_count(%{usage: nil}), do: "--"

  defp token_count(%{usage: usage}) do
    usage_value(usage, :total_tokens)
    |> case do
      0 -> "0"
      value -> Integer.to_string(value)
    end
  end

  defp token_breakdown(%{usage: nil}, _key), do: "--"

  defp token_breakdown(%{usage: usage}, key) do
    usage_value(usage, key)
    |> Integer.to_string()
  end

  defp format_profile(nil), do: "--"
  defp format_profile(profile) when is_atom(profile), do: Atom.to_string(profile)
  defp format_profile(profile), do: to_string(profile)

  defp usage_value(nil, _key), do: 0

  defp usage_value(%_{} = usage, key) do
    usage
    |> Map.from_struct()
    |> usage_value(key)
  end

  defp usage_value(usage, key) when is_map(usage) do
    usage[key] || usage[Atom.to_string(key)] || 0
  end

  defp usage_value(_usage, _key), do: 0

  defp render_payload(nil), do: "--"

  defp render_payload(data) do
    inspect(data, pretty: true, limit: :infinity)
  end

  defp http_entries(nil), do: []

  defp http_entries(http) do
    [
      {"Method", http_value(http, :method)},
      {"URL", http_value(http, :url)},
      {"Status", http_value(http, :status)},
      {"Request headers", format_headers(http_value(http, :request_headers))},
      {"Response headers", format_headers(http_value(http, :response_headers))}
    ]
    |> Enum.filter(fn {_label, value} -> value not in [nil, ""] end)
  end

  defp http_value(http, key) do
    http[key] || http[Atom.to_string(key)]
  end

  defp format_headers(nil), do: nil
  defp format_headers(headers), do: inspect(headers, limit: :infinity)

  defp event_label(%{type: :iteration_start, metadata: %{} = meta}) do
    case meta_value(meta, :iteration) do
      nil -> "Iteration started"
      iter -> "Iteration #{iter} started"
    end
  end

  defp event_label(%{type: :iteration_stop, metadata: %{} = meta}) do
    iter = meta_value(meta, :iteration)
    status = meta_value(meta, :status) || :ok
    base = if iter, do: "Iteration #{iter}", else: "Iteration"
    "#{base} #{status}"
  end

  defp event_label(%{type: :tool_start, metadata: meta}) do
    "Tool #{meta_value(meta, :tool_name) || "unknown"} dispatched"
  end

  defp event_label(%{type: :tool_complete, metadata: meta}) do
    result = meta_value(meta, :status) || :success
    "Tool #{meta_value(meta, :tool_name) || "unknown"} #{result}"
  end

  defp event_label(%{type: :tool_decision, metadata: meta}) do
    "Tool decision: #{meta_value(meta, :tool_name) || "unspecified"}"
  end

  defp event_label(%{type: :tool_retry, metadata: meta}) do
    "Tool #{meta_value(meta, :tool_name) || "unknown"} retrying"
  end

  defp event_label(%{type: :tool_error, metadata: meta}) do
    "Tool #{meta_value(meta, :tool_name) || "unknown"} error"
  end

  defp event_label(%{type: :token_limit_warning}), do: "Token limit warning"
  defp event_label(%{type: :token_limit_progress}), do: "Token milestone"

  defp event_label(%{type: :hook_start, metadata: meta}) do
    "Hook #{meta_value(meta, :hook_name) || "unknown"} started"
  end

  defp event_label(%{type: :hook_stop, metadata: meta}) do
    "Hook #{meta_value(meta, :hook_name) || "unknown"} completed"
  end

  defp event_label(%{type: :hook_error, metadata: meta}) do
    "Hook #{meta_value(meta, :hook_name) || "unknown"} error"
  end

  defp event_label(%{type: :progressive_process_results}),
    do: "Progressive disclosure (process results)"

  defp event_label(%{type: :progressive_sliding_window}),
    do: "Progressive disclosure (sliding window)"

  defp event_label(%{type: :progressive_token_based}), do: "Progressive disclosure (token based)"
  defp event_label(%{type: :prompt_rendered}), do: "Prompt rendered"
  defp event_label(%{type: :llm_request}), do: "LLM request"
  defp event_label(%{type: :llm_response, metadata: meta}) do
    "LLM response #{meta_value(meta, :status) || ""}"
  end

  defp event_label(%{type: :call_summary}), do: "Run summary"
  defp event_label(%{type: :annotation}), do: "Annotation"
  defp event_label(_event), do: "Event"

  defp event_details(%{type: :tool_start, metadata: meta}) do
    if args = meta_value(meta, :arguments) do
      "Arguments: #{inspect(args, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :tool_complete, metadata: meta}) do
    cond do
      result = meta_value(meta, :result) ->
        "Result: #{inspect(result, limit: :infinity)}"

      error = meta_value(meta, :error) ->
        "Error: #{inspect(error, limit: :infinity)}"

      true ->
        nil
    end
  end

  defp event_details(%{type: :token_limit_warning, metadata: meta, measurements: meas}) do
    tokens = meta_value(meta, :cumulative_tokens) || meas[:cumulative_tokens]
    limit = meta_value(meta, :limit)
    threshold = meta_value(meta, :threshold_percent)

    "Cumulative tokens #{tokens || "--"} of limit #{limit || "--"} (threshold #{threshold || "--"}%)"
  end

  defp event_details(%{type: :token_limit_progress, metadata: meta, measurements: meas}) do
    tokens = meta_value(meta, :cumulative_tokens) || meas[:cumulative_tokens]
    threshold = meta_value(meta, :threshold_percent)
    "Token usage at #{threshold || "--"}%: #{tokens || "--"} tokens"
  end

  defp event_details(%{type: :iteration_stop, measurements: meas}) do
    if duration = format_native_duration(meas[:duration]) do
      "Iteration completed in #{duration}"
    end
  end

  defp event_details(%{type: :hook_stop, metadata: meta, measurements: meas}) do
    if duration = format_native_duration(meas[:duration]) do
      "#{meta_value(meta, :hook_name) || "Hook"} completed in #{duration}"
    end
  end

  defp event_details(%{type: :hook_error, metadata: meta}) do
    if error = meta_value(meta, :error) do
      "Error: #{inspect(error, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :tool_decision, metadata: meta}) do
    considered = meta_value(meta, :considered)
    if considered do
      "Considered: #{inspect(considered, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :tool_retry, metadata: meta}) do
    if error = meta_value(meta, :error) do
      "Retrying after error: #{inspect(error, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :tool_error, metadata: meta}) do
    if error = meta_value(meta, :error) do
      "Error: #{inspect(error, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :prompt_rendered, metadata: meta, measurements: meas}) do
    length = meas[:length]
    preview = meta_value(meta, :prompt_preview)
    parts =
      [
        length && "Length: #{length} bytes",
        preview && "Preview: #{preview}"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " · ")
  end

  defp event_details(%{type: :llm_request, metadata: meta}) do
    iter = meta_value(meta, :iteration)
    if iter, do: "Iteration #{iter}", else: nil
  end

  defp event_details(%{type: :llm_response, metadata: meta}) do
    status = meta_value(meta, :status)
    iter = meta_value(meta, :iteration)
    [iter && "Iteration #{iter}", status && "Status: #{status}"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp event_details(%{type: :call_summary, metadata: meta}) do
    parts =
      [
        meta_value(meta, :status) && "Status: #{meta_value(meta, :status)}",
        meta_value(meta, :usage) && "Usage: #{inspect(meta_value(meta, :usage), limit: :infinity)}",
        meta_value(meta, :finish_reason) && "Finish: #{meta_value(meta, :finish_reason)}",
        meta_value(meta, :input) && "Input: #{inspect(meta_value(meta, :input), limit: :infinity)}",
        meta_value(meta, :result) && "Result: #{inspect(meta_value(meta, :result), limit: :infinity)}"
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, " · ")
  end

  defp event_details(%{type: :annotation, metadata: meta}) do
    if note = meta_value(meta, :message) do
      "Note: #{note}"
    end
  end

  defp event_details(%{type: :progressive_process_results, metadata: meta}) do
    if opts = meta_value(meta, :options) do
      "Options: #{inspect(opts, limit: :infinity)}"
    end
  end

  defp event_details(%{type: :progressive_sliding_window, metadata: meta}) do
    if size = meta_value(meta, :window_size) do
      "Window size: #{size}"
    end
  end

  defp event_details(%{type: :progressive_token_based, metadata: meta}) do
    budget = meta_value(meta, :budget)
    threshold = meta_value(meta, :threshold)
    "Budget #{budget || "--"} · Threshold #{threshold || "--"}"
  end

  defp event_details(%{metadata: meta, measurements: meas}) do
    parts = [
      present_map("Metadata", meta),
      present_map("Measurements", meas)
    ]

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp event_details(_), do: nil

  defp meta_value(metadata, key) when is_map(metadata) do
    metadata[key] || metadata[Atom.to_string(key)]
  end

  defp meta_value(_, _), do: nil

  defp present_map(_label, nil), do: nil
  defp present_map(_label, map) when map == %{}, do: nil

  defp present_map(label, map) do
    "#{label}: #{inspect(map, limit: :infinity)}"
  end

  defp format_native_duration(nil), do: nil

  defp format_native_duration(value) do
    ms = System.convert_time_unit(value, :native, :millisecond)
    "#{ms} ms"
  end
end
