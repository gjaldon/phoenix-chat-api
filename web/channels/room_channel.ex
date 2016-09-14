defmodule PhoenixChat.RoomChannel do
  use PhoenixChat.Web, :channel
  require Logger

  alias PhoenixChat.{Message, Repo, AnonymousUser}

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

  defp message_payload(message) do
    message = Repo.preload(message, :anonymous_user)
    anonymous_user = message.anonymous_user
    from = message.user_id || anonymous_user.name
    %{body: message.body,
      timestamp: message.timestamp,
      room: message.room,
      from: from,
      uuid: anonymous_user && anonymous_user.id,
      id: message.id}
  end

  def handle_in("message", payload, socket) do
    case record_message(socket, payload) do
      {:ok, message} ->
        payload = message_payload(message)
        broadcast! socket, "message", payload
        {:reply, :ok, socket}
      {:error, changeset} ->
        {:reply, {:error, %{errors: changeset}}, socket}
    end
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
      Repo.update!(AnonymousUser.last_message_changeset(user, user_params))
      Repo.insert!(Message.changeset(%Message{}, msg_params))
    end)
  end

  defp update_last_viewed_at(nil), do: nil #noop

  defp update_last_viewed_at(uuid) do
    user = Repo.get(AnonymousUser, uuid)
    changeset = AnonymousUser.last_viewed_changeset(user)
    Repo.update!(changeset)
  end
end
