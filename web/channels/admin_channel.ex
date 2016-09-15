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
        |> user_payload
      {:ok, %{lobby_list: lobby_list}, socket}
    end)
  end

  @doc """
  Handles the `:after_join` event and tracks the presence of the socket that has
  subscribed to the `admin:active_users` topic.
  """
  def handle_info(:after_join, socket) do
    track_presence(socket, socket.assigns)
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

  def user_payload(list) when is_list(list) do
    Enum.map(list, &user_payload/1)
  end

  def user_payload(user) do
    %{name: user.name,
      avatar: user.avatar,
      id: user.id,
      public_key: user.public_key,
      last_viewed_by_admin_at: user.last_viewed_by_admin_at}
  end

  defp track_presence(socket, %{uuid: uuid} = assigns) do
    user = Repo.get(AnonymousUser, uuid)
    user = if user do
        user
      else
        params = %{public_key: assigns.public_key, id: uuid}
        changeset = AnonymousUser.changeset(%AnonymousUser{}, params)
        Repo.insert!(changeset)
      end

    payload = user_payload(user)
    # Keep track of rooms to be displayed to admins
    broadcast! socket, "lobby_list", payload
    # Keep track of users that are online (not keepin track of admin presence)
    push socket, "presence_state", Presence.list(socket)
    {:ok, _} = Presence.track(socket, uuid, %{
      online_at: inspect(System.system_time(:seconds))
    })
  end

  # Noop when user is not anonymous (has no uuid)
  defp track_presence(_socket, _), do: nil #noop
end
