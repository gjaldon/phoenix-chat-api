defmodule PhoenixChat.RoomChannel do
  use PhoenixChat.Web, :channel
  require Logger

  alias PhoenixChat.{Message, Repo, AnonymousUser, Endpoint, AdminChannel}

  def join("room:" <> room_id, payload, socket) do
    authorize(payload, fn ->
      update_last_viewed_at(payload["previousRoom"])
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
      {:ok, %{user: user, message: message}} ->
        user_payload = AdminChannel.user_payload(user)
        broadcast! socket, "message", message_payload(message, user)
        Endpoint.broadcast_from! self, "admin:active_users",
          "lobby_list", user_payload
        Endpoint.broadcast_from! self, "admin:active_users",
          "notifications", user_payload
      {:ok, message} ->
        broadcast! socket, "message", message_payload(message)
    end
    {:reply, :ok, socket}
  end

  defp record_message(%{assigns: %{user_id: user_id}}, payload)when not is_nil(user_id) do
    msg_params = payload |> Map.put("user_id", user_id)
    changeset = Message.changeset(%Message{}, msg_params)
    Repo.insert(changeset)
  end

  defp record_message(%{assigns: %{uuid: uuid}}, payload) when not is_nil(uuid) do
    msg_params = payload |> Map.put("anonymous_user_id", uuid)
    user_params =  %{last_message: payload["body"], last_message_sent_at: msg_params["timestamp"]}
    user = Repo.get(AnonymousUser, uuid)

    Repo.transaction(fn ->
      user = Repo.update!(AnonymousUser.last_message_changeset(user, user_params))
      msg = Repo.insert!(Message.changeset(%Message{}, msg_params))
      %{user: user, message: msg}
    end)
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
    %{body: message.body,
      timestamp: message.timestamp,
      room: message.room,
      from: user.name,
      uuid: user.id,
      id: message.id}
  end
end
