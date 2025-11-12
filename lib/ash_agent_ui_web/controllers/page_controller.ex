defmodule AshAgentUiWeb.PageController do
  use AshAgentUiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
