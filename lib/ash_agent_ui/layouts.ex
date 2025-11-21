defmodule AshAgentUi.Layouts do
  use Phoenix.Component

  slot :inner_block
  attr :flash, :map, default: %{}
  attr :page_title, :string, default: nil

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-emerald-50/50 via-white to-white text-zinc-900 transition-colors dark:from-[#060b15] dark:via-[#0b1120] dark:to-[#070b14] dark:text-zinc-100">
      <header class="sticky top-0 z-30 border-b border-emerald-100/80 bg-white/85 backdrop-blur dark:border-white/10 dark:bg-[#0b1120]/85">
        <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-2xl bg-emerald-500/90 text-sm font-bold text-emerald-950 shadow-[0_15px_40px_-25px_rgba(16,185,129,0.9)]">
              UI
            </div>
            <div>
              <p class="text-[11px] font-semibold uppercase tracking-[0.24em] text-emerald-800/80 dark:text-emerald-100/80">
                Ash Agent UI
              </p>
              <p class="text-sm font-medium text-zinc-700 dark:text-zinc-300">
                Live observability for Ash agents
              </p>
            </div>
          </div>
          <div class="inline-flex items-center gap-2 rounded-full border border-emerald-200/70 bg-emerald-50/80 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-emerald-800 shadow-sm dark:border-white/10 dark:bg-white/10 dark:text-emerald-100">
            <span class="inline-flex h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            Live metrics
          </div>
        </div>
      </header>

      <main class="relative mx-auto max-w-6xl px-6 pb-14 pt-10 lg:pt-14">
        <div class="pointer-events-none absolute inset-x-0 top-0 h-60 bg-[radial-gradient(circle_at_20%_20%,rgba(16,185,129,0.14),transparent_35%),radial-gradient(circle_at_80%_0%,rgba(59,130,246,0.14),transparent_30%)] blur-3xl opacity-70 dark:opacity-40" />
        <div class="relative space-y-10 lg:space-y-14">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>
    """
  end
end
