defmodule AshAgentUi.RouterTest do
  use ExUnit.Case, async: true

  defmodule TestRouter do
    use Phoenix.Router
    import Phoenix.LiveView.Router
    use AshAgentUi.Router

    pipeline :browser do
      plug :accepts, ["html"]
    end

    scope "/" do
      pipe_through :browser
      ash_agent_ui("/ash-agent-ui")
    end
  end

  test "defines live routes at the given path" do
    routes = Phoenix.Router.routes(TestRouter)

    assert Enum.any?(routes, fn route ->
             route.plug == Phoenix.LiveView.Plug and route.path == "/ash-agent-ui"
           end)

    assert Enum.any?(routes, fn route ->
             route.plug == Phoenix.LiveView.Plug and route.path == "/ash-agent-ui/runs/:id"
           end)
  end

  test "rejects non-string paths" do
    message =
      assert_raise ArgumentError, fn ->
        defmodule BrokenRouter do
          use Phoenix.Router
          import Phoenix.LiveView.Router
          use AshAgentUi.Router

          scope "/" do
            ash_agent_ui(123)
          end
        end
      end

    assert Exception.message(message) =~ "expects a string path"
  end
end
