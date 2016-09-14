defmodule PhoenixChat.LobbyList do

  @table __MODULE__

  @doc """
  Create an :ets table for this module. We set the `:bag` option so that we can
  store multiple values with the same keys.
  """
  def init do
    opts = [:public, :named_table, {:write_concurrency, true}, {:read_concurrency, false}, :set]
    :ets.new(@table, opts)
  end

  def insert(public_key, uuid, fake_name, fake_avatar) do
    :ets.insert(@table, {uuid, public_key, fake_name, fake_avatar})
  end

  def delete(uuid) do
    :ets.delete(@table, uuid)
  end

  def lookup(public_key) do
    @table
    |> :ets.match({:'$1', public_key, :'$2', :'$3'})
    |> Enum.map(fn [uuid, fake_name, fake_avatar] ->
      %{id: uuid, name: fake_name, avatar: fake_avatar}
    end)
  end
end
