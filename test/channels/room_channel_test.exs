defmodule PhoenixChat.RoomChannelTest do
  use PhoenixChat.ChannelCase

  alias PhoenixChat.{RoomChannel, Message}

  setup do
    {:ok, %{messages: []}, socket} =
      socket("user_id", %{uuid: "1144", user_id: nil})
      |> subscribe_and_join(RoomChannel, "room:lobby")
    {:ok, socket: socket}
  end

  test "joining a room returns messages from the DB as payload" do
    timestamp = Ecto.DateTime.utc()
    Repo.insert!(%Message{body: "Foo", timestamp: timestamp, room: "1"})
    Repo.insert!(%Message{body: "Bar", timestamp: timestamp, room: "1"})
    Repo.insert!(%Message{body: "Bar", timestamp: timestamp, room: "2"})

    {:ok, %{messages: messages}, _} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(RoomChannel, "room:1")

    assert length(messages) == 2
  end

  test "message replies with status ok and saves message to DB", %{socket: socket} do
    payload = %{
      body: "hello",
      timestamp: 1470637865914,
      room: "lobby",
      from: "1144"
    }

    ref = push socket, "message", payload
    assert_reply ref, :ok, payload
    assert Repo.get_by(Message, payload)
  end

end
