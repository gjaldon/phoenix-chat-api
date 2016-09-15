defmodule PhoenixChat.Repo.Migrations.CreateAnonymousUsers do
  use Ecto.Migration

  def change do
    create table(:anonymous_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :avatar, :string
      add :public_key, :string
      add :last_viewed_by_admin_at, :datetime

      timestamps
    end
  end
end
