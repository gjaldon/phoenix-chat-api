defmodule PhoenixChat do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(PhoenixChat.Endpoint, []),
      # Start the Ecto repository
      supervisor(PhoenixChat.Repo, []),
      supervisor(PhoenixChat.Presence, [])
    ]
    # Ensure that we create :ets table for PhoenixChat.LobbyList
    PhoenixChat.LobbyList.init

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PhoenixChat.Endpoint.config_change(changed, removed)
    :ok
  end
end
