defmodule AshAgentUi.AssetController do
  use Phoenix.Controller, formats: [:json]

  def show(conn, %{"asset" => asset}) do
    path = Path.join(:code.priv_dir(:ash_agent_ui), "static/assets/#{asset}")

    if File.exists?(path) do
      conn
      |> put_resp_content_type(MIME.from_path(path))
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Not Found")
    end
  end
end
