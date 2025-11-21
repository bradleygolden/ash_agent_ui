defmodule AshAgentUi.Observe.Components do
  @moduledoc false
  use Phoenix.Component

  attr(:label, :string, required: true)
  attr(:value, :string, required: true)
  attr(:hint, :string, default: nil)
  attr(:badge, :string, default: nil)
  attr(:secondary_text, :string, default: nil)

  def stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-200 bg-white px-4 py-3 dark:border-zinc-800 dark:bg-zinc-900">
      <div class="flex items-center justify-between">
        <p class="text-xs font-medium text-zinc-600 dark:text-zinc-400">
          {@label}
        </p>
        <%= if assigns[:badge] do %>
          <span class="inline-flex items-center rounded-full bg-zinc-100 px-2 py-0.5 text-[10px] font-medium text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400">
            {@badge}
          </span>
        <% end %>
      </div>
      <div class="mt-1 flex items-baseline gap-2">
        <p class="text-2xl font-semibold text-zinc-900 dark:text-white">
          {@value}
        </p>
        <%= if @secondary_text do %>
          <span class="text-xs font-medium text-zinc-500 dark:text-zinc-400">{@secondary_text}</span>
        <% end %>
      </div>
    </div>
    """
  end

  attr(:status, :atom, required: true)

  def status_badge(assigns) do
    ~H"""
    <span class={status_classes(@status)}>
      <%= if @status == :ok do %>
        <svg class="mr-1.5 h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
        </svg>
      <% else %>
        <span class={["mr-1.5 h-1.5 w-1.5 rounded-full", status_dot_classes(@status)]}></span>
      <% end %>
      {format_status(@status)}
    </span>
    """
  end

  defp status_classes(:running),
    do:
      "inline-flex items-center rounded-md bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700 ring-1 ring-inset ring-indigo-700/10 dark:bg-indigo-400/10 dark:text-indigo-400 dark:ring-indigo-400/30"

  defp status_classes(:ok),
    do:
      "inline-flex items-center rounded-md bg-transparent px-0 py-1 text-xs font-medium text-emerald-600 dark:text-emerald-400"

  defp status_classes(:error),
    do:
      "inline-flex items-center rounded-md bg-rose-50 px-2 py-1 text-xs font-medium text-rose-700 ring-1 ring-inset ring-rose-600/10 dark:bg-rose-400/10 dark:text-rose-400 dark:ring-rose-400/20"

  defp status_classes(_),
    do:
      "inline-flex items-center rounded-md bg-slate-50 px-2 py-1 text-xs font-medium text-slate-600 ring-1 ring-inset ring-slate-500/10 dark:bg-slate-400/10 dark:text-slate-400 dark:ring-slate-400/20"

  defp status_dot_classes(:running), do: "bg-indigo-600 dark:bg-indigo-400 animate-pulse"
  defp status_dot_classes(:ok), do: "bg-emerald-500 dark:bg-emerald-400"
  defp status_dot_classes(:error), do: "bg-rose-500 dark:bg-rose-400"
  defp status_dot_classes(_), do: "bg-slate-500 dark:bg-slate-400"

  defp format_status(status) when is_atom(status),
    do: status |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp format_status(status), do: status
end
