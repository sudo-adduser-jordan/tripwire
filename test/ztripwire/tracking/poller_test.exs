defmodule Ztripwire.Tracking.PollerTest do
  use Ztripwire.DataCase, async: false

  alias Ztripwire.Accounts.Character
  alias Ztripwire.ESI.TokenCache
  alias Ztripwire.Mapping
  alias Ztripwire.Masks
  alias Ztripwire.Tracking.Poller
  alias Ztripwire.Tracking.Presence

  setup do
    previous = Application.get_env(:ztripwire, Ztripwire.ESI)
    on_exit(fn -> Application.put_env(:ztripwire, Ztripwire.ESI, previous) end)

    eve_id = 900_000 + System.unique_integer([:positive])
    character = %Character{eve_id: eve_id, name: "Poller Test", refresh_token: "refresh"}
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Poller Home", mask_id: mask.id})

    TokenCache.put(eve_id, %{
      access_token: "access",
      refresh_token: "refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
    })

    on_exit(fn ->
      TokenCache.delete(eve_id)
      Presence.remove_viewer(eve_id)
    end)

    {:ok, character: character, map: map}
  end

  test "polls only the online endpoint while the character is offline", %{
    character: character,
    map: map
  } do
    stub(self(), online: false)
    Presence.add_viewer(character.eve_id)

    {:ok, _pid} = start_poller(character, map)

    assert_receive {:esi, :online}, 1_000
    refute_receive {:esi, :location}, 200
    refute_receive {:esi, :ship}, 200
  end

  test "follows location and ship only while online and watched", %{
    character: character,
    map: map
  } do
    stub(self(), online: true)
    Presence.add_viewer(character.eve_id)
    assert Presence.viewers(character.eve_id) == 1

    {:ok, _pid} = start_poller(character, map)

    assert_receive {:esi, :online}, 1_000
    assert_receive {:esi, :location}, 1_000
    assert_receive {:esi, :ship}, 1_000
  end

  test "does not follow location without a dashboard viewer", %{
    character: character,
    map: map
  } do
    stub(self(), online: true)

    {:ok, _pid} = start_poller(character, map)

    assert_receive {:esi, :online}, 1_000
    refute_receive {:esi, :location}, 200
    refute_receive {:esi, :ship}, 200
  end

  defp stub(pid, opts) do
    config =
      :ztripwire
      |> Application.get_env(Ztripwire.ESI, [])
      |> Keyword.merge(
        cache: false,
        req_options: [plug: {Ztripwire.PollerESIStub, Keyword.put(opts, :pid, pid)}]
      )

    Application.put_env(:ztripwire, Ztripwire.ESI, config)
  end

  defp start_poller(character, map) do
    start_supervised(
      {Poller,
       character: character,
       map: map,
       interval: 20,
       online_interval: 20,
       idle_interval: 20,
       jitter: 0}
    )
  end
end
