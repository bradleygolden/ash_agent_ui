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
      |> assign(:runs, runs)
      |> assign(:stats, build_stats(runs))
      |> assign(:base_path, base_path)
      |> assign(:streaming?, true)
      |> assign(:connected?, connected?)

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
    runs = upsert(socket.assigns.runs, run, 50)
    {:noreply, assign(socket, runs: runs, stats: build_stats(runs))}
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
        |> assign(:runs, runs)
        |> assign(:stats, build_stats(runs))
      else
        assign(socket, :streaming?, false)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="mx-auto max-w-6xl space-y-12 px-4 pb-14 pt-6 md:px-6">
        <header class="relative overflow-hidden rounded-4xl border border-emerald-100/80 bg-gradient-to-br from-emerald-50/80 via-white to-emerald-50/50 p-8 shadow-[0_28px_90px_-60px_rgba(16,185,129,0.4)] backdrop-blur-md dark:border-white/10 dark:from-white/5 dark:via-white/10 dark:to-white/0 dark:shadow-[0_30px_90px_-70px_rgba(0,0,0,0.75)] lg:p-10">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_18%_22%,rgba(16,185,129,0.16),transparent_40%),radial-gradient(circle_at_88%_0%,rgba(59,130,246,0.16),transparent_30%)]" />
          <div class="relative flex flex-col gap-8 lg:flex-row lg:items-start lg:justify-between">
            <div class="space-y-5">
              <div class="flex flex-wrap items-center gap-3 text-[11px] font-semibold uppercase tracking-[0.22em] text-emerald-800 dark:text-emerald-100">
                <span class="inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1.5 shadow-sm ring-1 ring-emerald-100/80 dark:bg-white/10 dark:ring-white/10">
                  <span class="inline-flex h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
                  Live metrics
                </span>
                <span class="inline-flex items-center gap-2 rounded-full bg-white/80 px-3 py-1.5 text-emerald-900 ring-1 ring-emerald-100/80 dark:bg-white/5 dark:text-emerald-50 dark:ring-white/10">
                  <span class={connection_dot_class(@connected?)} />
                  {connection_label(@connected?)}
                </span>
              </div>
              <div class="space-y-2">
                <h1 class="text-4xl font-semibold text-zinc-900 drop-shadow-md dark:text-white">
                  Observability dashboard
                </h1>
                <p class="max-w-3xl lg:max-w-4xl text-base leading-relaxed text-zinc-600 dark:text-zinc-200/80">
                  Monitor real-time agent executions, tool activity, and token spend via PubSub. Leave this tab open while agents run elsewhere, and pause/resume streaming when you need to inspect a static view.
                </p>
              </div>
              <p class="text-xs text-zinc-500 dark:text-zinc-300">
                Base: {@base_path} · Window: last 50 runs · Streaming via PubSub — toggle below to freeze the view.
              </p>
            </div>
            <div class="self-start rounded-2xl border border-emerald-100/80 bg-gradient-to-br from-emerald-50/90 via-white to-white px-4 py-3 text-sm leading-relaxed font-medium text-emerald-800 shadow-[0_20px_70px_-50px_rgba(16,185,129,0.7)] ring-1 ring-emerald-100/50 dark:border-white/10 dark:from-white/10 dark:via-white/5 dark:to-white/0 dark:text-emerald-100 dark:ring-white/10 lg:max-w-sm">
              Live-run telemetry streams straight from PubSub. Keep this page open to watch runs, tokens, and HTTP details update; pause streaming below to freeze the current view while you review entries.
            </div>
          </div>
        </header>

        <div class="space-y-8 lg:space-y-10">
          <div class="grid gap-7 sm:grid-cols-3">
            <Components.stat_card
              label="Active Runs"
              value={@stats.active_runs}
              hint="Currently running agents"
              badge="Live"
              caption="Auto-refreshes while streaming is on."
            />
            <Components.stat_card
              label="Success Rate"
              value={@stats.success_rate}
              hint="Across last 50 runs"
              badge="Rolling"
              caption="Calculated over the latest 50 runs."
            />
            <Components.stat_card
              label="Tokens"
              value={@stats.token_total}
              hint="Total tokens consumed"
              badge="Usage"
              caption="Input and output tokens combined (latest 50 runs)."
            />
          </div>

        <div class="overflow-hidden rounded-3xl border border-emerald-100/70 bg-white/90 shadow-[0_30px_90px_-60px_rgba(0,0,0,0.3)] backdrop-blur dark:border-white/10 dark:bg-white/5 dark:shadow-[0_30px_90px_-70px_rgba(0,0,0,0.75)]">
          <div class="flex flex-col gap-3 border-b border-emerald-100/80 px-5 py-3.5 text-sm text-zinc-600 dark:border-white/5 dark:text-zinc-300 md:flex-row md:items-center md:justify-between">
            <div class="space-y-0.5">
              <p class="text-xs font-semibold uppercase tracking-wide text-emerald-800/80 dark:text-emerald-100/80">
                Recent runs
              </p>
              <p>Latest 50 executions with live updates.</p>
            </div>
            <div class="flex flex-wrap items-center gap-3 rounded-2xl border border-emerald-100/80 bg-gradient-to-r from-white to-emerald-50/60 px-4 py-2.5 text-xs font-semibold text-emerald-800 shadow-[0_10px_35px_-30px_rgba(16,185,129,0.6)] dark:border-white/10 dark:from-white/5 dark:to-white/10 dark:text-emerald-100">
              <span class="inline-flex items-center gap-2 rounded-xl bg-white/80 px-3 py-1 ring-1 ring-emerald-100/80 dark:bg-white/5 dark:ring-white/10">
                Stream control
              </span>
              <span class={streaming_badge_classes(@streaming?)}>
                <span class={streaming_dot_class(@streaming?)} />
                {if @streaming?, do: "Streaming", else: "Paused"}
              </span>
              <button
                type="button"
                phx-click="toggle_streaming"
                class={streaming_button_classes(@streaming?)}
              >
                <span class="inline-flex h-2 w-2 rounded-full bg-current opacity-70" />
                <%= if @streaming?, do: "Pause live", else: "Resume live" %>
              </button>
            </div>
          </div>
          <%= if Enum.empty?(@runs) do %>
            <div class="px-6 py-12 text-center text-sm text-zinc-600 dark:text-zinc-400">
              <div class="mx-auto mb-3 inline-flex h-10 w-10 items-center justify-center rounded-full bg-emerald-50 text-emerald-700 ring-1 ring-emerald-100/70 dark:bg-white/10 dark:text-emerald-100 dark:ring-white/10">
                <span class="text-base font-semibold">i</span>
              </div>
              <p class="font-semibold text-zinc-700 dark:text-zinc-200">No runs captured yet.</p>
              <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
                Trigger a demo agent from the workbench home to populate live metrics, then keep this page open to stream updates.
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="w-full min-w-[820px] text-left text-sm">
                <thead class="bg-emerald-50/80 text-xs uppercase tracking-[0.18em] text-emerald-800 dark:bg-white/5 dark:text-emerald-100">
                  <tr>
                    <th class="px-4 py-2.5">Agent</th>
                    <th class="px-4 py-2.5">Type</th>
                    <th class="px-4 py-2.5">Status</th>
                    <th class="px-4 py-2.5">Started</th>
                    <th class="px-4 py-2.5 text-right">Duration</th>
                    <th class="px-4 py-2.5 text-right">Tokens</th>
                    <th class="px-4 py-2.5 text-right">Details</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-emerald-100/70 dark:divide-white/5">
                  <%= for run <- @runs do %>
                    <tr class="transition-colors hover:bg-emerald-50/60 dark:hover:bg-white/10">
                      <td class="px-4 py-2.5">
                        <div class="flex flex-col gap-1">
                          <p class="font-mono text-sm text-zinc-900 dark:text-white">
                            {inspect(run.agent)}
                          </p>
                          <p class="text-[11px] text-zinc-400 dark:text-zinc-500">
                            Provider {inspect(run.provider)} · Profile {format_profile(run.profile)} · Client {inspect(run.client)}
                          </p>
                        </div>
                      </td>
                      <td class="px-4 py-2.5 text-zinc-600 dark:text-zinc-300">
                        <span class="rounded-full bg-emerald-50/70 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-emerald-800 ring-1 ring-emerald-100/80 dark:bg-white/5 dark:text-emerald-100 dark:ring-white/10">
                          {run.type}
                        </span>
                      </td>
                      <td class="px-4 py-2.5"><Components.status_badge status={run.status} /></td>
                      <td class="px-4 py-2.5 text-zinc-600 dark:text-zinc-300">
                        <div class="flex flex-col gap-1">
                          <span class="font-mono text-sm text-zinc-800 dark:text-zinc-200">
                            {format_datetime(run.started_at)}
                          </span>
                          <span class="text-xs text-zinc-500 dark:text-zinc-400">
                            {format_relative(run.started_at)}
                          </span>
                        </div>
                      </td>
                      <td class="px-4 py-2.5 text-right font-mono text-sm text-zinc-800 dark:text-zinc-200">
                        {format_duration(run.duration_ms)}
                      </td>
                      <td class="px-4 py-2.5 text-right font-mono text-sm text-zinc-800 dark:text-zinc-200">
                        {token_count(run)}
                      </td>
                      <td class="px-4 py-2.5 text-right">
                        <a
                          class="inline-flex items-center gap-1 rounded-full border border-emerald-200/70 bg-emerald-50/80 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-800 transition hover:-translate-y-[1px] hover:bg-emerald-100 dark:border-white/10 dark:bg-white/10 dark:text-emerald-100"
                          href={Path.join(@base_path, "runs/#{run.id}")}
                        >
                          View
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
      </section>
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
    "#{total} (in #{input} / out #{output})"
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

  defp streaming_dot_class(true),
    do: "inline-flex h-2 w-2 rounded-full bg-emerald-500 animate-pulse"

  defp streaming_dot_class(false),
    do: "inline-flex h-2 w-2 rounded-full bg-amber-400"

  defp streaming_badge_classes(true),
    do:
      "inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-800 ring-1 ring-emerald-100/80 dark:bg-white/10 dark:text-emerald-100 dark:ring-white/10"

  defp streaming_badge_classes(false),
    do:
      "inline-flex items-center gap-2 rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-amber-900 ring-1 ring-amber-200/80 dark:bg-amber-500/20 dark:text-amber-100 dark:ring-amber-400/50"

  defp streaming_button_classes(true),
    do:
      "inline-flex items-center gap-2 rounded-full border border-emerald-200/70 bg-white/90 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-emerald-800 shadow-sm transition hover:-translate-y-[1px] hover:bg-emerald-50 dark:border-white/10 dark:bg-white/5 dark:text-emerald-100"

  defp streaming_button_classes(false),
    do:
      "inline-flex items-center gap-2 rounded-full border border-emerald-400 bg-emerald-600 px-3 py-1.5 text-xs font-semibold uppercase tracking-wide text-white shadow-sm transition hover:-translate-y-[1px] hover:shadow-md"

  defp connection_dot_class(true),
    do:
      "inline-flex h-2.5 w-2.5 rounded-full bg-emerald-500 shadow-[0_0_0_4px_rgba(16,185,129,0.15)]"

  defp connection_dot_class(false),
    do:
      "inline-flex h-2.5 w-2.5 rounded-full bg-amber-500 shadow-[0_0_0_4px_rgba(245,158,11,0.2)]"

  defp connection_label(true), do: "Connected"
  defp connection_label(false), do: "Awaiting socket"
end
