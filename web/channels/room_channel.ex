defmodule PhoenixChat.RoomChannel do
  use PhoenixChat.Web, :channel
  require Logger

  alias PhoenixChat.{Message, Repo, AnonymousUser, Endpoint, AdminChannel}

  def join("room:" <> room_id, payload, socket) do
    authorize(payload, fn ->
      record_anonymous_user(socket)
      update_last_viewed_at(payload["previousRoom"])
      update_last_viewed_at(payload["nextRoom"])
      messages = room_id
        |> Message.latest_room_messages
        |> Repo.all
        |> Enum.map(&message_payload/1)
        |> Enum.reverse
      {:ok, %{messages: messages}, socket}
    end)
  end

  def handle_in("message", payload, socket) do
    case record_message(socket, payload) do
      {:ok, %{anonymous_user_id: uuid} = message} when not is_nil(uuid) ->
        user = Repo.preload(message, :anonymous_user).anonymous_user
        message_payload = message_payload(message, user)
        broadcast! socket, "message", message_payload
        Endpoint.broadcast_from! self, "admin:active_users",
          "lobby_list", AdminChannel.user_payload(user)
        Endpoint.broadcast_from! self, "admin:active_users",
          "notifications", message_payload
      {:ok, message} ->
        broadcast! socket, "message", message_payload(message)
    end
    {:reply, :ok, socket}
  end

  # Record anonymous user if not yet recorded so we can track the last message
  # sent and when their chat channel was last viewed by an admin.
  defp record_anonymous_user(%{uuid: uuid} = assigns) do
    if !Repo.get(AnonymousUser, uuid) do
      params = %{public_key: assigns.public_key, id: uuid}
      changeset = AnonymousUser.changeset(%AnonymousUser{}, params)
      Repo.insert!(changeset)
    end
  end

  # We do not need to record signed-up users
  defp record_anonymous_user(_socket), do: nil #noop

  defp record_message(%{assigns: %{user_id: user_id}}, payload)when not is_nil(user_id) do
    msg_params = payload |> Map.put("user_id", user_id)
    changeset = Message.changeset(%Message{}, msg_params)
    Repo.insert(changeset)
  end

  defp record_message(%{assigns: %{uuid: uuid}}, payload) when not is_nil(uuid) do
    msg_params = payload |> Map.put("anonymous_user_id", uuid)
    Repo.insert(Message.changeset(%Message{}, msg_params))
  end

  defp update_last_viewed_at(nil), do: nil #noop

  defp update_last_viewed_at(uuid) do
    user = Repo.get(AnonymousUser, uuid)
    changeset = AnonymousUser.last_viewed_changeset(user)
    user = Repo.update!(changeset)
    Endpoint.broadcast_from! self, "admin:active_users",
      "lobby_list", AdminChannel.user_payload(user)
  end

  defp message_payload(message, user) do
    %{body: message.body,
      timestamp: message.timestamp,
      room: message.room,
      from: user.name,
      uuid: user.id,
      id: message.id}
  end

  defp message_payload(%{anonymous_user_id: nil} = message) do
    %{body: message.body,
      timestamp: message.timestamp,
      room: message.room,
      from: message.user_id,
      id: message.id}
  end

  defp message_payload(message) do
    message = Repo.preload(message, :anonymous_user)
    user = message.anonymous_user
    message_payload(message, user)
  end
end
