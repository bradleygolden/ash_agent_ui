# AshAgentUi

An embeddable Phoenix LiveView surface for inspecting and orchestrating Ash agents.

The package is meant to be pulled into an existing Phoenix application (for example, the web tier that already boots your agents). There is no standalone endpoint or server inside this repo—think of it like `Phoenix.LiveDashboard`, but specialized for agents.

## Installation

Add the dependency (path or hex, depending on how you consume the mono-repo):

```elixir
def deps do
  [
    {:ash_agent_ui, path: "../ash_agent_ui"}
  ]
end
```

Fetch deps with `mix deps.get`.

## Mounting the UI

Mount the provided router macro anywhere inside your application's router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAgentUi.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
  end

  scope "/" do
    pipe_through [:browser, :require_authenticated_user]
    ash_agent_ui "/ash-agent-ui", as: :agents
  end
end
```

- `ash_agent_ui/2` expects the mount path as the first argument.
- Pass `:as` to customize the helper prefix (`:ash_agent_ui` by default).

The LiveView currently renders scaffolding to confirm wiring; future commits will stream agent runs, BAML tools, and related instrumentation.

## Development

Useful tasks:

- `mix deps.get` – install dependencies
- `mix test` – run the library test suite
- `mix format` – format Elixir and HEEx files

No asset compilation or Phoenix endpoint exists in this project—the host application provides HTTP, authentication, and static assets.
