defmodule PhoenixChat.AdminChannel do
  @moduledoc """
  The channel used to give the administrator access to all users.
  """

  use PhoenixChat.Web, :channel

  alias PhoenixChat.{Presence, Repo, AnonymousUser}

  intercept ~w(lobby_list)

  @doc """
  The `admin:active_users` topic is how we identify all users currently using the app.
  """
  def join("admin:active_users", payload, socket) do
    authorize(payload, fn ->
      send(self, :after_join)

      public_key = socket.assigns.public_key
      lobby_list = public_key
        |> AnonymousUser.by_public_key
        |> Repo.all
        |> AnonymousUser.json_serialize
      {:ok, %{lobby_list: lobby_list}, socket}
    end)
  end

  @doc """
  Handles the `:after_join` event and tracks the presence of the socket that has subscribed to the `admin:active_users` topic.
  """
  def handle_info(:after_join, socket) do
    %{assigns: assigns} = socket

    # Record anonymous user if not yet recorded so we can track the last message
    # sent and when their chat channel was last viewed by an admin.
    uuid = assigns[:uuid]
    if uuid && !Repo.get(AnonymousUser, uuid) do
      params = %{public_key: assigns.public_key, id: uuid}
      changeset = AnonymousUser.changeset(%AnonymousUser{}, params)
      Repo.insert!(changeset)
    end

    id = assigns.user_id || assigns.uuid
    # Keep track of rooms to be displayed to admins
    broadcast! socket, "lobby_list", %{uuid: id, public_key: assigns.public_key}
    # Keep track of users that are online
    push socket, "presence_state", Presence.list(socket)
    {:ok, _} = Presence.track(socket, id, %{
        online_at: inspect(System.system_time(:seconds))
      })
    {:noreply, socket}
  end

  @doc """
  Sends the lobby_list only to admins
  """
  def handle_out("lobby_list", payload, socket) do
    %{assigns: assigns} = socket
    if assigns.user_id && assigns.public_key == payload.public_key do
      push socket, "lobby_list", payload
    end
    {:noreply, socket}
  end
end
