defmodule ParserTestWeb.PageController do
  use ParserTestWeb, :controller

  def home(conn, params) do
    json(conn, %{params: params})
  end
end
