defmodule AshAgentUi.Observe.Components do
  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :hint, :string, default: nil
  attr :badge, :string, default: nil
  attr :caption, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-2xl border border-emerald-100/80 bg-gradient-to-br from-white via-emerald-50/40 to-white px-6 py-7 shadow-[0_24px_60px_-42px_rgba(16,185,129,0.55)] ring-1 ring-emerald-100/70 transition hover:-translate-y-[2px] hover:shadow-[0_28px_70px_-42px_rgba(16,185,129,0.65)] dark:border-white/10 dark:from-white/5 dark:via-white/10 dark:to-white/0 dark:ring-white/10">
      <div class="absolute inset-x-0 top-0 h-1 bg-gradient-to-r from-emerald-300 via-emerald-400 to-emerald-200 opacity-70 transition group-hover:opacity-100" />
      <div class="relative flex flex-col gap-3">
        <div class="flex items-center gap-3">
          <p class="text-[11px] font-semibold uppercase tracking-[0.22em] text-emerald-800 dark:text-emerald-100">
            {@label}
          </p>
          <%= if @badge do %>
            <span class="inline-flex items-center gap-2 rounded-full bg-emerald-100/80 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-emerald-900 ring-1 ring-emerald-200/90 dark:bg-white/10 dark:text-emerald-100 dark:ring-white/10">
              {@badge}
            </span>
          <% end %>
        </div>
        <p class="text-4xl leading-tight font-semibold text-emerald-900 drop-shadow-sm dark:text-white">
          {@value}
        </p>
        <%= if @hint do %>
          <p class="text-sm leading-relaxed text-zinc-600 dark:text-zinc-400">{@hint}</p>
        <% end %>
        <%= if @caption do %>
          <p class="text-[11px] leading-relaxed text-emerald-800/80 dark:text-emerald-100/80">{@caption}</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={status_classes(@status)}>
      {format_status(@status)}
    </span>
    """
  end

  defp status_classes(:running),
    do:
      "inline-flex items-center gap-1 rounded-full bg-amber-500/20 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-amber-900 ring-1 ring-amber-400/50 dark:text-amber-100 dark:ring-amber-400/40"

  defp status_classes(:ok),
    do:
      "inline-flex items-center gap-1 rounded-full bg-emerald-500/20 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-emerald-900 ring-1 ring-emerald-400/50 dark:text-emerald-100 dark:ring-emerald-400/40"

  defp status_classes(:error),
    do:
      "inline-flex items-center gap-1 rounded-full bg-rose-500/20 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-rose-900 ring-1 ring-rose-400/50 dark:text-rose-100 dark:ring-rose-400/40"

  defp status_classes(_),
    do:
      "inline-flex items-center gap-1 rounded-full bg-zinc-200 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-zinc-800 ring-1 ring-black/5 dark:bg-white/5 dark:text-zinc-200 dark:ring-white/10"

  defp format_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.upcase()

  defp format_status(status), do: status
end
