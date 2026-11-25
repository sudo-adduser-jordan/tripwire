defmodule Tripwire.MasksTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Accounts, Mapping, Masks}

  test "ensure_personal_mask/1 creates one global Private mask" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 1, name: "Tester"})
    {:ok, other} = Accounts.upsert_character(%{eve_id: 11, name: "Other Tester"})

    {:ok, mask} = Masks.ensure_personal_mask(character)
    assert mask.kind == "personal"
    assert mask.name == "Private"
    assert is_nil(mask.owner_character_id)

    {:ok, reused} = Masks.ensure_personal_mask(other)
    assert reused.id == mask.id
  end

  test "add_membership/2 is idempotent" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 2, name: "Tester Two"})
    {:ok, mask} = Masks.ensure_personal_mask(character)

    assert {:ok, _} = Masks.add_membership(mask, character)
    assert {:ok, _} = Masks.add_membership(mask, character)

    assert length(Masks.list_masks_for_character(character.id)) == 1
  end

  test "list_masks/0 returns every non-demo mask ordered by kind then name" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 6, name: "Tester Six"})
    {:ok, personal} = Masks.ensure_personal_mask(character)
    {:ok, corp_z} = Masks.create_mask(%{name: "Zeta Corp", kind: "corporation"})
    {:ok, corp_a} = Masks.create_mask(%{name: "Alpha Corp", kind: "corporation"})
    {:ok, alliance} = Masks.create_mask(%{name: "Big Alliance", kind: "alliance"})
    _demo = Tripwire.TestFixtures.demo_mask()

    masks = Masks.list_masks()

    assert Enum.map(masks, & &1.id) == [personal.id, corp_a.id, corp_z.id, alliance.id]
    refute Enum.any?(masks, &(&1.kind == "demo"))
  end

  test "a map can be created under a personal mask and systems added to it" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 3, name: "Tester Three"})
    {:ok, mask} = Masks.ensure_personal_mask(character)

    {:ok, map} = Mapping.create_map(%{name: "Home Chain", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{
        solar_system_id: 31_000_000,
        name: "J150321",
        x: 100.0,
        y: 50.0
      })

    assert [%Mapping.MapSystem{} = loaded] = Mapping.list_systems(map.id)
    assert loaded.id == system.id
    assert loaded.name == "J150321"
  end

  test "signature changeset validates format and uniqueness per system" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 4, name: "Tester Four"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Sig Map", mask_id: mask.id})
    {:ok, system} = Mapping.add_system_to_map(map, %{solar_system_id: 1, name: "J000000"})

    changeset = signature_changeset(system, %{sig_id: "abc-123"})
    assert changeset.valid?

    assert {:ok, _} = Repo.insert(changeset)

    duplicate = signature_changeset(system, %{sig_id: "ABC-123"})
    assert {:error, _} = Repo.insert(duplicate)

    invalid = signature_changeset(system, %{sig_id: "nope"})
    refute invalid.valid?
  end

  test "delete_mask_full/1 hard-deletes the mask with maps and memberships" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 5, name: "Admin Tester"})
    {:ok, mask} = Masks.ensure_personal_mask(character)
    {:ok, map} = Mapping.create_map(%{name: "Gone Chain", mask_id: mask.id})

    {:ok, system} =
      Mapping.add_system_to_map(map, %{solar_system_id: 31_000_099, name: "J999999"})

    {:ok, _} = Masks.add_membership(mask, character)

    assert {:ok, _} = Masks.delete_mask_full(mask)

    assert Masks.list_masks_for_character(character.id) == []
    assert Mapping.list_maps_for_mask(mask.id) == []
    assert Mapping.list_systems(map.id) == []
    assert Mapping.list_signatures(system.id) == []
  end

  test "prune_orphan_masks/0 removes masks with no character in their corporation or alliance" do
    {:ok, character} =
      Accounts.upsert_character(%{
        eve_id: 7,
        name: "Corp Pilot Seven",
        corporation_id: 98_000_010,
        alliance_id: 99_000_010
      })

    {:ok, personal} = Masks.ensure_personal_mask(character)
    {:ok, corp} = Masks.ensure_corporation_mask(character)
    {:ok, alliance} = Masks.ensure_alliance_mask(character)
    {:ok, ownerless} = Masks.create_mask(%{name: "Ownerless Corp", kind: "corporation"})
    {:ok, corp_map} = Mapping.create_map(%{name: "Corp Chain", mask_id: corp.id})
    _demo = Tripwire.TestFixtures.demo_mask()

    assert Masks.prune_orphan_masks() == []

    {:ok, _} =
      Accounts.update_character(character, %{corporation_id: 98_000_011, alliance_id: nil})

    pruned = Masks.prune_orphan_masks()

    assert Enum.sort(Enum.map(pruned, & &1.id)) == Enum.sort([corp.id, alliance.id])
    assert Mapping.list_maps_for_mask(corp_map.mask_id) == []

    assert Enum.sort(Enum.map(Masks.list_masks(), & &1.id)) ==
             Enum.sort([personal.id, ownerless.id])
  end

  test "prune_orphan_masks/0 keeps a corporation mask while another character matches" do
    {:ok, one} =
      Accounts.upsert_character(%{
        eve_id: 8,
        name: "Corp Pilot Eight",
        corporation_id: 98_000_020
      })

    {:ok, two} =
      Accounts.upsert_character(%{
        eve_id: 9,
        name: "Corp Pilot Nine",
        corporation_id: 98_000_020
      })

    {:ok, mask} = Masks.ensure_corporation_mask(one)

    {:ok, _} = Accounts.update_character(one, %{corporation_id: 98_000_021})

    assert Masks.prune_orphan_masks() == []
    assert Enum.any?(Masks.list_masks(), &(&1.id == mask.id))

    {:ok, _} = Accounts.delete_character(two)

    assert [%{id: id}] = Masks.prune_orphan_masks()
    assert id == mask.id
  end

  test "prune_orphan_masks/0 skips while any character corporation is unknown" do
    {:ok, known} =
      Accounts.upsert_character(%{
        eve_id: 10,
        name: "Known Corp Pilot",
        corporation_id: 98_000_030
      })

    {:ok, unknown} = Accounts.upsert_character(%{eve_id: 11, name: "Unsynced Pilot"})
    {:ok, mask} = Masks.ensure_corporation_mask(known)

    {:ok, alliance} =
      Masks.create_mask(%{name: "Orphan Alliance", kind: "alliance", eve_owner_id: 99_000_030})

    assert Masks.prune_orphan_masks() == []
    assert Enum.any?(Masks.list_masks(), &(&1.id == mask.id))
    assert Enum.any?(Masks.list_masks(), &(&1.id == alliance.id))

    {:ok, _} = Accounts.update_character(unknown, %{corporation_id: 98_000_031})

    assert Enum.map(Masks.prune_orphan_masks(), & &1.id) == [alliance.id]
    assert Enum.any?(Masks.list_masks(), &(&1.id == mask.id))
  end

  defp signature_changeset(system, attrs) do
    Mapping.Signature.changeset(
      %Mapping.Signature{},
      Map.merge(%{map_system_id: system.id}, attrs)
    )
  end
end
