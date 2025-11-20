defmodule AshAgentUi.Observe.Run do
  @moduledoc false
  @enforce_keys [:id, :agent, :provider, :client, :type, :status, :started_at]
  defstruct [
    :id,
    :type,
    :agent,
    :provider,
    :profile,
    :client,
    :status,
    :started_at,
    :completed_at,
    :inserted_at,
    :duration_ms,
    :usage,
    :input,
    :result,
    :error,
    :response_id,
    :response_model,
    :finish_reason,
    :provider_meta,
    :http,
    events: []
  ]
end
