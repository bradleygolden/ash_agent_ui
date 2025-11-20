defmodule AshAgentUi do
  @moduledoc """
  Entry point for Ash Agent UI's embeddable surfaces.

  The library exposes a router macro (`AshAgentUi.Router`) that can be mounted inside any Phoenix
  application's router, similar to `Phoenix.LiveDashboard.Router`. The UI itself streams data from
  Ash Agent and Ash BAML, so the host application only needs to provide authentication and pipelines.
  """
end
