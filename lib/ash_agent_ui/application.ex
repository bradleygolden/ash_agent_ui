defmodule AshAgentUi.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: AshAgentUi.PubSub},
      {AshAgentUi.Observe.Store, []},
      {AshAgentUi.Observe.Telemetry, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AshAgentUi.Supervisor)
  end
end
