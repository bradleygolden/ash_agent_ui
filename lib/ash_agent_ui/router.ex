defmodule AshAgentUi.Router do
  @moduledoc """
  Routing helpers for embedding Ash Agent UI screens, modeled after `Phoenix.LiveDashboard.Router`.

  Import (or `use`) the helper from inside your router, wrap it in whatever scopes/pipelines you need,
  and pass the mount path as the first argument:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use AshAgentUi.Router

        scope "/" do
          pipe_through [:browser, :require_user]
          ash_agent_ui "/ash-agent-ui"
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import AshAgentUi.Router
    end
  end

  defmacro ash_agent_ui(path, opts \\ []) do
    validated_path = validate_path!(path)

    quote bind_quoted: [path: validated_path, opts: opts], location: :keep do
      scope_opts = [as: Keyword.get(opts, :as, :ash_agent_ui), alias: false]

      scope path, scope_opts do
        live_session :ash_agent_ui, session: %{"ash_agent_ui_base_path" => path} do
          live "/", AshAgentUi.OverviewLive, :home
          live "/runs/:id", AshAgentUi.RunLive, :run
        end
      end
    end
  end

  defp validate_path!(<<"/"::binary, _::binary>> = path), do: path

  defp validate_path!(path) when is_binary(path) do
    raise ArgumentError,
          "ash_agent_ui/2 expects paths to start with \"/\", got: #{inspect(path)}"
  end

  defp validate_path!(path) do
    raise ArgumentError, "ash_agent_ui/2 expects a string path, got: #{inspect(path)}"
  end
end
