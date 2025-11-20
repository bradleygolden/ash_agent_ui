defmodule AshAgentUi.Observe do
  @moduledoc false
  alias AshAgentUi.Observe.Store

  defdelegate list_runs(opts \\ []), to: Store
  defdelegate fetch_run(id), to: Store
  defdelegate start_run(attrs), to: Store
  defdelegate update_run(id, attrs), to: Store
  defdelegate append_event(id, event), to: Store
  defdelegate clear(), to: Store
end
