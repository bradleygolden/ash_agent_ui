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
      |> assign(:active_tab, :payloads)

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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} base_path={@base_path}>
      <div class="h-full flex flex-col gap-4">
        <!-- Header -->
        <div class="shrink-0 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <a
              href={@base_path}
              class="group flex items-center justify-center w-8 h-8 rounded-full bg-white border border-slate-200 text-slate-500 hover:border-indigo-500 hover:text-indigo-600 transition-colors dark:bg-white/5 dark:border-white/10 dark:text-slate-400 dark:hover:border-indigo-400 dark:hover:text-indigo-400"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="2.5"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18"
                />
              </svg>
            </a>
            <div>
              <div class="flex items-center gap-3">
                <h1 class="text-lg font-bold uppercase tracking-wider text-slate-900 dark:text-white">
                  {inspect(@run.agent)}
                </h1>
                <Components.status_badge status={@run.status} />
              </div>
              <div class="flex items-center gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
                <span>{inspect(@run.client)}</span>
                <span class="text-slate-300 dark:text-slate-600">•</span>
                <span>{inspect(@run.provider)}</span>
                <span class="text-slate-300 dark:text-slate-600">•</span>
                <span>{format_profile(@run.profile)}</span>
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-xs font-mono text-slate-400 dark:text-slate-500">
              {format_datetime(@run.started_at)}
            </span>
          </div>
        </div>
        
    <!-- Metrics -->
        <div class="shrink-0 grid grid-cols-3 gap-4">
          <Components.stat_card
            label="DURATION"
            value={format_duration(@run.duration_ms)}
            secondary_text="execution time"
          />
          <Components.stat_card
            label="TOTAL TOKENS"
            value={token_count(@run)}
            secondary_text="usage"
          />
          <Components.stat_card
            label="INPUT / OUTPUT"
            value={token_breakdown(@run, :input_tokens)}
            secondary_text={"/ #{token_breakdown(@run, :output_tokens)}"}
          />
        </div>
        
    <!-- Main Content -->
        <div class="flex-1 min-h-0 grid grid-cols-1 lg:grid-cols-3 gap-4">
          <!-- Left Column: Data Tabs -->
          <div class="lg:col-span-2 flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-white/5 dark:bg-white/5">
            <div class="shrink-0 border-b border-slate-200 px-4 dark:border-white/5">
              <nav class="-mb-px flex space-x-6" aria-label="Tabs">
                <button
                  type="button"
                  phx-click="switch_tab"
                  phx-value-tab="payloads"
                  class={[
                    "whitespace-nowrap border-b-2 py-3 px-1 text-xs font-bold uppercase tracking-wider transition-colors",
                    @active_tab == :payloads &&
                      "border-indigo-500 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400",
                    @active_tab != :payloads &&
                      "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700 dark:text-slate-400 dark:hover:border-slate-700 dark:hover:text-slate-300"
                  ]}
                >
                  Payloads
                </button>
                <button
                  type="button"
                  phx-click="switch_tab"
                  phx-value-tab="metadata"
                  class={[
                    "whitespace-nowrap border-b-2 py-3 px-1 text-xs font-bold uppercase tracking-wider transition-colors",
                    @active_tab == :metadata &&
                      "border-indigo-500 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400",
                    @active_tab != :metadata &&
                      "border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700 dark:text-slate-400 dark:hover:border-slate-700 dark:hover:text-slate-300"
                  ]}
                >
                  Metadata
                </button>
                <%= if @run.error do %>
                  <button
                    type="button"
                    phx-click="switch_tab"
                    phx-value-tab="error"
                    class={[
                      "whitespace-nowrap border-b-2 py-3 px-1 text-xs font-bold uppercase tracking-wider transition-colors",
                      @active_tab == :error &&
                        "border-rose-500 text-rose-600 dark:border-rose-400 dark:text-rose-400",
                      @active_tab != :error &&
                        "border-transparent text-slate-500 hover:border-rose-300 hover:text-rose-700 dark:text-slate-400 dark:hover:border-rose-700 dark:hover:text-rose-300"
                    ]}
                  >
                    Error
                  </button>
                <% end %>
              </nav>
            </div>

            <div class="flex-1 overflow-y-auto p-4">
              <%= case @active_tab do %>
                <% :payloads -> %>
                  <div class="space-y-6">
                    <section>
                      <div class="flex items-center justify-between mb-2">
                        <h3 class="text-xs font-bold uppercase tracking-wider text-slate-900 dark:text-white">
                          Input
                        </h3>
                      </div>
                      <div class="rounded-lg border border-slate-200 bg-slate-50 p-4 dark:border-white/5 dark:bg-[#0B1120]/50">
                        <pre class="overflow-x-auto text-xs font-mono text-slate-700 dark:text-slate-300">{render_payload(@run.input)}</pre>
                      </div>
                    </section>

                    <section>
                      <div class="flex items-center justify-between mb-2">
                        <h3 class="text-xs font-bold uppercase tracking-wider text-slate-900 dark:text-white">
                          Result
                        </h3>
                      </div>
                      <div class="rounded-lg border border-slate-200 bg-slate-50 p-4 dark:border-white/5 dark:bg-[#0B1120]/50">
                        <pre class="overflow-x-auto text-xs font-mono text-slate-700 dark:text-slate-300">{render_payload(@run.result)}</pre>
                      </div>
                    </section>
                  </div>
                <% :metadata -> %>
                  <div class="space-y-6">
                    <%= if @run.http do %>
                      <section>
                        <h3 class="text-xs font-bold uppercase tracking-wider text-slate-900 dark:text-white mb-2">
                          HTTP Metadata
                        </h3>
                        <div class="rounded-lg border border-slate-200 bg-slate-50 p-4 dark:border-white/5 dark:bg-[#0B1120]/50">
                          <dl class="space-y-3 text-xs">
                            <%= for {label, value} <- http_entries(@run.http) do %>
                              <div>
                                <dt class="font-medium text-slate-500 dark:text-slate-400">
                                  {label}
                                </dt>
                                <dd class="mt-1 font-mono text-slate-700 break-all dark:text-slate-300">
                                  {value}
                                </dd>
                              </div>
                            <% end %>
                          </dl>
                        </div>
                      </section>
                    <% end %>

                    <%= if @run.provider_meta do %>
                      <section>
                        <h3 class="text-xs font-bold uppercase tracking-wider text-slate-900 dark:text-white mb-2">
                          Provider Metadata
                        </h3>
                        <div class="rounded-lg border border-slate-200 bg-slate-50 p-4 dark:border-white/5 dark:bg-[#0B1120]/50">
                          <pre class="overflow-x-auto text-xs font-mono text-slate-700 dark:text-slate-300">{render_payload(@run.provider_meta)}</pre>
                        </div>
                      </section>
                    <% end %>

                    <%= if !@run.http && !@run.provider_meta do %>
                      <div class="text-center py-12 text-sm text-slate-500 dark:text-slate-400">
                        No metadata available.
                      </div>
                    <% end %>
                  </div>
                <% :error -> %>
                  <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 dark:border-rose-500/20 dark:bg-rose-500/10">
                    <pre class="overflow-x-auto text-xs font-mono text-rose-900 dark:text-rose-100">{render_payload(@run.error)}</pre>
                  </div>
              <% end %>
            </div>
          </div>
          
    <!-- Right Column: Timeline -->
          <div class="flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-white/5 dark:bg-white/5">
            <div class="shrink-0 border-b border-slate-200 px-4 py-3 dark:border-white/5">
              <h3 class="text-xs font-bold uppercase tracking-wider text-slate-900 dark:text-white">
                Timeline
              </h3>
            </div>
            <div class="flex-1 overflow-y-auto">
              <%= if Enum.empty?(@events) do %>
                <div class="px-4 py-8 text-center text-xs text-slate-500 dark:text-slate-400">
                  No events captured yet.
                </div>
              <% else %>
                <ul class="divide-y divide-slate-100 dark:divide-white/5">
                  <%= for event <- @events do %>
                    <li class="px-4 py-3 hover:bg-slate-50 dark:hover:bg-white/5 transition-colors">
                      <div class="flex flex-col gap-1">
                        <div class="flex items-start justify-between gap-2">
                          <span class="text-xs font-medium text-slate-700 dark:text-slate-300">
                            {event_label(event)}
                          </span>
                          <span class="shrink-0 text-[10px] font-mono text-slate-400 dark:text-slate-500">
                            {format_time_only(event.timestamp)}
                          </span>
                        </div>
                        <%= if details = event_details(event) do %>
                          <p class="text-[11px] text-slate-500 dark:text-slate-400 line-clamp-2">
                            {details}
                          </p>
                        <% end %>
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>
        </div>
      </div>
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

  defp format_time_only(nil), do: "--"

  defp format_time_only(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S.%3f")
  end

  defp format_duration(nil), do: "--"
  defp format_duration(ms) when is_number(ms), do: Integer.to_string(ms) <> " ms"

  defp token_count(%{usage: nil}), do: "--"

  defp token_count(%{usage: usage}) do
    total =
      usage_value(usage, :total_tokens)
      |> case do
        0 -> "0"
        value -> Integer.to_string(value)
      end

    input = usage_value(usage, :input_tokens)
    output = usage_value(usage, :output_tokens)

    assigns = %{total: total, input: input, output: output}

    ~H"""
    <span>
      {@total}
      <span class="text-slate-400 dark:text-slate-500">
        (<span class="text-emerald-600 dark:text-emerald-400">↓{@input}</span> / <span class="text-blue-600 dark:text-blue-400">↑{@output}</span>)
      </span>
    </span>
    """
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
        meta_value(meta, :usage) &&
          "Usage: #{inspect(meta_value(meta, :usage), limit: :infinity)}",
        meta_value(meta, :finish_reason) && "Finish: #{meta_value(meta, :finish_reason)}",
        meta_value(meta, :input) &&
          "Input: #{inspect(meta_value(meta, :input), limit: :infinity)}",
        meta_value(meta, :result) &&
          "Result: #{inspect(meta_value(meta, :result), limit: :infinity)}"
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
