defmodule AshAgentUi.OverviewLive do
  use Phoenix.LiveView

  alias AshAgentUi.Layouts
  alias AshAgentUi.Observe
  alias AshAgentUi.Observe.Components

  @impl true
  def mount(_params, session, socket) do
    base_path =
      session["ash_agent_ui_base_path"] || socket.private[:ash_agent_ui_base_path] || "/"

    {:ok, runs} = Observe.list_runs(limit: 50)
    connected? = connected?(socket)

    socket =
      socket
      |> assign(:all_runs, runs)
      |> assign(:runs, runs)
      |> assign(:stats, build_stats(runs))
      |> assign(:base_path, base_path)
      |> assign(:streaming?, true)
      |> assign(:connected?, connected?)
      |> assign(:is_filter_open, false)
      |> assign(:filter_options, %{
        status: [],
        agent: [],
        type: []
      })

    if connected? do
      Phoenix.PubSub.subscribe(AshAgentUi.PubSub, "ash_agent_ui:runs")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({event, _run}, %{assigns: %{streaming?: false}} = socket)
      when event in [:run_started, :run_updated] do
    {:noreply, socket}
  end

  def handle_info({event, run}, socket) when event in [:run_started, :run_updated] do
    all_runs = upsert(socket.assigns.all_runs, run, 50)
    runs = apply_filters(all_runs, socket.assigns.filter_options)
    {:noreply, assign(socket, all_runs: all_runs, runs: runs, stats: build_stats(all_runs))}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_streaming", _params, socket) do
    streaming? = not socket.assigns.streaming?

    socket =
      if streaming? do
        {:ok, runs} = Observe.list_runs(limit: 50)

        socket
        |> assign(:streaming?, true)
        |> assign(:all_runs, runs)
        |> assign(:runs, apply_filters(runs, socket.assigns.filter_options))
        |> assign(:stats, build_stats(runs))
      else
        assign(socket, :streaming?, false)
      end

    {:noreply, socket}
  end

  def handle_event("toggle_filter", _params, socket) do
    {:noreply, assign(socket, :is_filter_open, not socket.assigns.is_filter_open)}
  end

  def handle_event("update_filter", params, socket) do
    filter_params = params["filter"] || %{}
    # Parse params (checkboxes send "true" or list of values)
    # We need to handle the form data structure
    
    # Normalize filter params
    status = 
      (filter_params["status"] || []) 
      |> Enum.reject(&(&1 == "false")) 
      |> Enum.map(&String.to_existing_atom/1)
    
    agent = filter_params["agent"] || []
    type = filter_params["type"] || []

    filter_options = %{
      status: status,
      agent: agent,
      type: type
    }

    runs = apply_filters(socket.assigns.all_runs, filter_options)
    
    {:noreply, assign(socket, filter_options: filter_options, runs: runs)}
  end

  defp apply_filters(runs, filters) do
    runs
    |> Enum.filter(fn run ->
      status_match? = Enum.empty?(filters.status) || run.status in filters.status
      agent_match? = Enum.empty?(filters.agent) || inspect(run.agent) in filters.agent
      type_match? = Enum.empty?(filters.type) || to_string(run.type) in filters.type
      
      status_match? && agent_match? && type_match?
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} base_path={@base_path}>
      <div class="h-full flex flex-col gap-4">
        <div class="shrink-0 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
              Dashboard
            </h1>
            <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
              Monitor agent executions and token usage
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span class={[
              "inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
              @connected? && "bg-emerald-50 text-emerald-700 ring-emerald-600/20 dark:bg-emerald-500/10 dark:text-emerald-400 dark:ring-emerald-500/20",
              !@connected? && "bg-slate-50 text-slate-600 ring-slate-500/10 dark:bg-slate-400/10 dark:text-slate-400 dark:ring-slate-400/20"
            ]}>
              <span class={[
                "h-1.5 w-1.5 rounded-full",
                @connected? && "bg-emerald-500 dark:bg-emerald-400",
                !@connected? && "bg-slate-400"
              ]} />
              {connection_label(@connected?)}
            </span>
          </div>
        </div>

        <div class="shrink-0 grid grid-cols-3 gap-4">
          <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
            <div class="flex items-center justify-between">
              <p class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">Active Runs</p>
              <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600 dark:bg-white/10 dark:text-slate-300">LIVE</span>
            </div>
            <div class="mt-2 flex items-baseline gap-2">
              <p class="text-3xl font-semibold text-slate-900 dark:text-white">{@stats.active_runs}</p>
              <p class="text-sm text-slate-500 dark:text-slate-400">threads</p>
            </div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
            <div class="flex items-center justify-between">
              <p class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">Success Rate</p>
              <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600 dark:bg-white/10 dark:text-slate-300">ROLLING</span>
            </div>
            <div class="mt-2 flex items-baseline gap-2">
              <p class="text-3xl font-semibold text-slate-900 dark:text-white">{@stats.success_rate}</p>
              <p class="text-sm font-medium text-emerald-600 dark:text-emerald-400">Ok</p>
            </div>
          </div>
          <div class="rounded-xl border border-slate-200 bg-white p-4 shadow-sm dark:border-white/5 dark:bg-white/5">
            <div class="flex items-center justify-between">
              <p class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">Total Tokens</p>
              <span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600 dark:bg-white/10 dark:text-slate-300">USAGE</span>
            </div>
            <div class="mt-2 flex items-baseline gap-2">
              <p class="text-3xl font-semibold text-slate-900 dark:text-white">{@stats.token_total}</p>
              <p class="text-sm text-slate-500 dark:text-slate-400">accumulated</p>
            </div>
          </div>
        </div>

        <div class="flex-1 min-h-0 flex flex-col overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm dark:border-white/5 dark:bg-white/5">
          <div class="shrink-0 flex items-center justify-between border-b border-slate-200 px-6 py-4 dark:border-white/5">
            <div class="flex items-baseline gap-4">
              <h2 class="text-base font-bold text-slate-900 dark:text-white">Recent Runs</h2>
              <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                <span class="text-slate-300 dark:text-slate-600">|</span>
                <span>Latest 50 executions</span>
              </div>
            </div>
            <div class="flex items-center gap-2">
          <div class="relative">
            <button
              type="button"
              phx-click="toggle_filter"
              class={[
                "inline-flex items-center gap-2 rounded-lg border px-3 py-1.5 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-indigo-500/20",
                @is_filter_open && "border-indigo-500 bg-indigo-50 text-indigo-700 dark:border-indigo-400 dark:bg-indigo-500/10 dark:text-indigo-400",
                !@is_filter_open && "border-slate-200 bg-white text-slate-700 hover:bg-slate-50 dark:border-white/10 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10"
              ]}
            >
              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 01-.659 1.591l-5.432 5.432a2.25 2.25 0 00-.659 1.591v2.927a2.25 2.25 0 01-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 00-.659-1.591L3.659 7.409A2.25 2.25 0 013 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0112 3z" />
              </svg>
              Filter
              <%= if filter_count(@filter_options) > 0 do %>
                <span class="ml-1 inline-flex items-center justify-center rounded-full bg-indigo-600 px-1.5 py-0.5 text-[10px] font-bold text-white dark:bg-indigo-400">
                  {filter_count(@filter_options)}
                </span>
              <% end %>
            </button>

            <%= if @is_filter_open do %>
              <div class="absolute right-0 top-full z-50 mt-2 w-72 rounded-xl border border-slate-200 bg-white p-4 shadow-xl ring-1 ring-slate-200 dark:border-white/10 dark:bg-[#1E293B] dark:ring-white/10">
                <form phx-change="update_filter">
                  <div class="space-y-5">
                    <!-- Status Filter -->
                    <div>
                      <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-3">Status</h3>
                      <div class="space-y-2">
                        <%= for status <- [:ok, :error, :running] do %>
                          <label class="flex items-center gap-2 cursor-pointer group">
                            <input
                              type="checkbox"
                              name="filter[status][]"
                              value={status}
                              checked={status in @filter_options.status}
                              class="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-600 dark:border-white/10 dark:bg-white/5 dark:checked:bg-indigo-500"
                            />
                            <span class="text-sm font-medium text-slate-700 group-hover:text-slate-900 dark:text-slate-300 dark:group-hover:text-white transition-colors">
                              {format_status(status)}
                            </span>
                          </label>
                        <% end %>
                      </div>
                    </div>

                    <!-- Agent Filter -->
                    <div>
                      <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-3">Agent</h3>
                      <div class="space-y-2 max-h-40 overflow-y-auto pr-2 scrollbar-thin scrollbar-thumb-slate-200 dark:scrollbar-thumb-white/10">
                        <%= for agent <- unique_values(@all_runs, :agent) do %>
                          <label class="flex items-center gap-2 cursor-pointer group">
                            <input
                              type="checkbox"
                              name="filter[agent][]"
                              value={inspect(agent)}
                              checked={inspect(agent) in @filter_options.agent}
                              class="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-600 dark:border-white/10 dark:bg-white/5 dark:checked:bg-indigo-500"
                            />
                            <span class="text-sm font-medium text-slate-700 group-hover:text-slate-900 dark:text-slate-300 dark:group-hover:text-white transition-colors truncate">
                              {inspect(agent)}
                            </span>
                          </label>
                        <% end %>
                        <%= if Enum.empty?(unique_values(@all_runs, :agent)) do %>
                          <p class="text-xs text-slate-400 italic">No agents found</p>
                        <% end %>
                      </div>
                    </div>

                    <!-- Type Filter -->
                    <div>
                      <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-3">Type</h3>
                      <div class="space-y-2">
                        <%= for type <- unique_values(@all_runs, :type) do %>
                          <label class="flex items-center gap-2 cursor-pointer group">
                            <input
                              type="checkbox"
                              name="filter[type][]"
                              value={type}
                              checked={to_string(type) in @filter_options.type}
                              class="h-4 w-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-600 dark:border-white/10 dark:bg-white/5 dark:checked:bg-indigo-500"
                            />
                            <span class="text-sm font-medium text-slate-700 group-hover:text-slate-900 dark:text-slate-300 dark:group-hover:text-white transition-colors">
                              {type}
                            </span>
                          </label>
                        <% end %>
                        <%= if Enum.empty?(unique_values(@all_runs, :type)) do %>
                          <p class="text-xs text-slate-400 italic">No types found</p>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </form>
              </div>
            <% end %>
          </div>
              <button
                type="button"
                phx-click="toggle_streaming"
                class="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 dark:border-white/10 dark:bg-white/5 dark:text-slate-300 dark:hover:bg-white/10"
              >
                {if @streaming?, do: "Pause updates", else: "Resume updates"}
              </button>
            </div>
          </div>
          <%= if Enum.empty?(@runs) do %>
            <div class="flex-1 flex flex-col items-center justify-center px-6 py-16 text-center">
              <div class="mx-auto h-12 w-12 rounded-full bg-slate-50 flex items-center justify-center dark:bg-white/5">
                 <svg class="h-6 w-6 text-slate-400" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z" />
                </svg>
              </div>
              <h3 class="mt-3 text-sm font-semibold text-slate-900 dark:text-white">No runs yet</h3>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                Trigger an agent to see runs appear here
              </p>
            </div>
          <% else %>
            <div class="flex-1 overflow-auto">
              <table class="w-full text-sm text-left border-separate border-spacing-0">
                <thead class="sticky top-0 z-10 bg-slate-50 text-xs font-bold uppercase tracking-wider text-slate-500 dark:bg-[#1E293B] dark:text-slate-400 shadow-sm">
                  <tr>
                    <th class="px-6 py-3 border-b border-slate-200 dark:border-white/5">Agent</th>
                    <th class="px-6 py-3 border-b border-slate-200 dark:border-white/5">Type</th>
                    <th class="px-6 py-3 border-b border-slate-200 dark:border-white/5">Status</th>
                    <th class="px-6 py-3 border-b border-slate-200 dark:border-white/5">Started</th>
                    <th class="px-6 py-3 text-right border-b border-slate-200 dark:border-white/5">Duration</th>
                    <th class="px-6 py-3 text-right border-b border-slate-200 dark:border-white/5">Tokens</th>
                    <th class="px-6 py-3 text-right border-b border-slate-200 dark:border-white/5"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-200 dark:divide-white/5">
                  <%= for run <- @runs do %>
                    <tr class="group hover:bg-slate-50 dark:hover:bg-white/5 transition-colors">
                      <td class="px-6 py-4">
                        <p class="font-bold text-slate-900 dark:text-white">
                          {inspect(run.agent)}
                        </p>
                        <p class="mt-0.5 text-xs font-mono text-slate-500 dark:text-slate-400">
                          <span class="text-slate-300 dark:text-slate-600">•</span> {inspect(run.provider)} <span class="text-slate-300 dark:text-slate-600">•</span> {format_profile(run.profile)}
                        </p>
                      </td>
                      <td class="px-6 py-4">
                        <span class="inline-flex rounded-md bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 dark:bg-indigo-500/10 dark:text-indigo-400">
                          {run.type}
                        </span>
                      </td>
                      <td class="px-6 py-4"><Components.status_badge status={run.status} /></td>
                      <td class="px-6 py-4">
                        <p class="font-medium text-slate-900 dark:text-slate-200">
                          {format_datetime(run.started_at)}
                        </p>
                        <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                          {format_relative(run.started_at)}
                        </p>
                      </td>
                      <td class="px-6 py-4 text-right font-mono text-xs font-medium text-slate-600 dark:text-slate-400">
                        {format_duration(run.duration_ms)}
                      </td>
                      <td class="px-6 py-4 text-right font-mono text-xs font-medium text-slate-600 dark:text-slate-400">
                        {token_count(run)}
                      </td>
                      <td class="px-6 py-4 text-right">
                        <a
                          class="text-slate-400 hover:text-indigo-600 dark:text-slate-500 dark:hover:text-indigo-400 transition-colors"
                          href={Path.join(@base_path, "runs/#{run.id}")}
                        >
                          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          </svg>
                        </a>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp upsert(runs, run, limit) do
    [run | Enum.reject(runs, &(&1.id == run.id))]
    |> Enum.take(limit)
  end

  defp build_stats(runs) do
    total = max(length(runs), 1)
    success = Enum.count(runs, &(&1.status == :ok))
    active = Enum.count(runs, &(&1.status == :running))
    tokens = runs |> Enum.map(&token_sum/1) |> Enum.sum()

    %{
      success_rate: format_percent(success / total),
      active_runs: Integer.to_string(active),
      token_total: format_tokens(tokens)
    }
  end

  defp token_sum(%{usage: nil}), do: 0

  defp token_sum(%{usage: usage}) do
    usage_value(usage, :total_tokens)
  end

  defp format_percent(value) do
    :erlang.float_to_binary(Float.round(value * 100, 1), decimals: 1) <> "%"
  end

  defp format_tokens(tokens) when tokens >= 1000 do
    formatted = :erlang.float_to_binary(tokens / 1000, decimals: 1)
    formatted <> "k"
  end

  defp format_tokens(tokens), do: Integer.to_string(tokens)

  defp format_datetime(nil), do: "--"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d %H:%M:%S")
  end

  defp format_relative(nil), do: "--"

  defp format_relative(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  defp format_duration(nil), do: "--"
  defp format_duration(ms) when is_number(ms), do: Integer.to_string(ms) <> " ms"

  defp token_count(%{usage: nil}), do: "--"

  defp token_count(%{usage: usage} = run) do
    total = Integer.to_string(token_sum(run))
    input = usage_value(usage, :input_tokens)
    output = usage_value(usage, :output_tokens)

    assigns = %{total: total, input: input, output: output}

    ~H"""
    <span>{@total} <span class="text-slate-400 dark:text-slate-500">(<span class="text-emerald-600 dark:text-emerald-400">↓{@input}</span> / <span class="text-blue-600 dark:text-blue-400">↑{@output}</span>)</span></span>
    """
  end

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

  defp format_profile(nil), do: "--"
  defp format_profile(profile) when is_atom(profile), do: Atom.to_string(profile)
  defp format_profile(profile), do: to_string(profile)



  defp unique_values(runs, key) do
    runs
    |> Enum.map(&Map.get(&1, key))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp filter_count(options) do
    Enum.count(options.status) + Enum.count(options.agent) + Enum.count(options.type)
  end

  defp format_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_status(status), do: status

  defp connection_label(true), do: "Connected"
  defp connection_label(false), do: "Awaiting socket"
end
