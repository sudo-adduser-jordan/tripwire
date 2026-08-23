defmodule Tripwire.MasksTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.{Accounts, Mapping, Masks}

  test "ensure_personal_mask/1 creates and then reuses a personal mask" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 1, name: "Tester"})

    {:ok, mask} = Masks.ensure_personal_mask(character)
    assert mask.kind == "personal"
    assert mask.owner_character_id == character.id

    {:ok, reused} = Masks.ensure_personal_mask(character)
    assert reused.id == mask.id
  end

  test "add_membership/2 is idempotent" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 2, name: "Tester Two"})
    {:ok, mask} = Masks.ensure_personal_mask(character)

    assert {:ok, _} = Masks.add_membership(mask, character)
    assert {:ok, _} = Masks.add_membership(mask, character)

    assert length(Masks.list_masks_for_character(character.id)) == 1
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

  defp signature_changeset(system, attrs) do
    Mapping.Signature.changeset(
      %Mapping.Signature{},
      Map.merge(%{map_system_id: system.id}, attrs)
    )
  end
end
