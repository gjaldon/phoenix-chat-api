defmodule PhoenixChat.AnonymousUser do
  use PhoenixChat.Web, :model

  alias PhoenixChat.Message

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "anonymous_users" do
    field :name
    field :avatar
    field :public_key
    field :last_viewed_by_admin_at, PhoenixChat.DateTime
    has_many :messages, Message

    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(public_key id), ~w())
    |> put_avatar
    |> put_name
  end

  def last_message_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(last_message last_message_sent_at), [])
  end

  def last_viewed_changeset(model) do
    params = %{last_viewed_by_admin_at: System.system_time(:milliseconds)}
    model
    |> cast(params, ~w(last_viewed_by_admin_at), [])
  end

  def by_public_key(public_key, limit \\ 20) do
    from u in __MODULE__,
      join: m in Message, on: m.anonymous_user_id == u.id,
      where: u.public_key == ^public_key,
      limit: ^limit,
      distinct: u.id,
      order_by: [desc: m.inserted_at],
      select: {u, m}
  end

  defp put_name(changeset) do
    name = (Faker.Color.fancy_name <> " " <> Faker.Company.buzzword()) |> String.downcase
    changeset
    |> put_change(:name, name)
  end

  defp put_avatar(changeset) do
    changeset
    |> put_change(:avatar, Faker.Avatar.image_url(25, 25))
  end
end
