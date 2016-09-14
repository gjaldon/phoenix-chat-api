defmodule PhoenixChat.AnonymousUser do
  use PhoenixChat.Web, :model
  alias PhoenixChat.Organization

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "anonymous_users" do
    field :name
    field :avatar
    field :public_key
    field :last_message
    field :last_viewed_by_admin_at, :integer
    field :last_message_sent_at, :integer

    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(public_key id), ~w())
    |> put_avatar
    |> put_name
  end

  def by_public_key(public_key, limit \\ 20) do
    from u in __MODULE__,
      where: u.public_key == ^public_key,
      limit: ^limit
  end

  def json_serialize(list) do
    Enum.map(list, fn user ->
      %{name: user.name,
        avatar: user.avatar,
        id: user.id,
        last_message: user.last_message,
        last_message_sent_at: user.last_message_sent_at,
        last_viewed_by_admin_at: user.last_viewed_by_admin_at}
    end)
  end

  defp put_name(changeset) do
    name = (Faker.Color.name <> " " <> Faker.Company.buzzword()) |> String.downcase
    changeset
    |> put_change(:name, name)
  end

  defp put_avatar(changeset) do
    changeset
    |> put_change(:avatar, Faker.Avatar.image_url(25, 25))
  end
end
