defmodule PhoenixChat.LobbyList do

  @table __MODULE__

  @doc """
  Create an :ets table for this module. We set the `:bag` option so that we can
  store multiple values with the same keys.
  """
  def init do
    opts = [:public, :named_table, {:write_concurrency, true}, {:read_concurrency, false}, :bag]
    :ets.new(@table, opts)
  end

  def insert(public_key, uuid) do
    :ets.insert(@table, {public_key, uuid})
  end

  def delete(public_key) do
    :ets.delete(@table, public_key)
  end

  def lookup(public_key) do
    @table
    |> :ets.lookup(public_key)
    |> Enum.map(fn {_, uuid} -> uuid end)
  end
end
