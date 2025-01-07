defmodule ParserTestWeb.Router do
  use ParserTestWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ParserTestWeb do
     pipe_through :api
     post "/api", PageController, :home
   end
end
