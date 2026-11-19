defmodule Tripwire.AccountsTest do
  use Tripwire.DataCase, async: false

  alias Tripwire.Accounts

  @valid_attrs %{
    eve_id: 1234,
    name: "Kariyo Astrien",
    refresh_token: "secret-refresh-token",
    scopes: ["esi-location.read_location.v1"]
  }

  test "upsert_character/1 inserts a new character" do
    assert {:ok, character} = Accounts.upsert_character(@valid_attrs)
    assert character.eve_id == 1234
    assert character.name == "Kariyo Astrien"
    assert character.scopes == ["esi-location.read_location.v1"]
  end

  test "refresh_token is encrypted at rest but transparently decrypted on load" do
    {:ok, _} = Accounts.upsert_character(@valid_attrs)

    %{rows: [[stored]]} =
      Repo.query!("SELECT refresh_token FROM characters WHERE eve_id = 1234")

    refute stored == "secret-refresh-token"
    assert character = Accounts.get_character_by_eve_id(1234)
    assert character.refresh_token == "secret-refresh-token"
  end

  test "upsert_character/1 updates an existing character instead of duplicating" do
    {:ok, original} = Accounts.upsert_character(@valid_attrs)

    {:ok, updated} =
      Accounts.upsert_character(
        Map.merge(@valid_attrs, %{
          name: "Renamed Character",
          last_login_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
      )

    assert updated.id == original.id
    assert updated.name == "Renamed Character"
    assert length(Accounts.list_characters()) == 1
  end

  test "upsert_character/1 defaults is_admin to false and persists grants" do
    assert {:ok, character} = Accounts.upsert_character(@valid_attrs)
    refute character.is_admin

    assert {:ok, updated} = Accounts.upsert_character(%{eve_id: 1234, is_admin: true})
    assert updated.id == character.id
    assert updated.is_admin
  end

  test "update_character/2 toggles visibility flags" do
    {:ok, character} = Accounts.upsert_character(@valid_attrs)
    assert character.ship_on_chain
    assert character.character_on_chain

    assert {:ok, hidden} = Accounts.update_character(character, %{ship_on_chain: false})
    refute hidden.ship_on_chain
    assert hidden.character_on_chain

    assert %{ship_on_chain: false, character_on_chain: true} =
             Accounts.get_character(character.id)

    assert {:ok, visible} =
             Accounts.update_character(hidden, %{ship_on_chain: true, character_on_chain: true})

    assert visible.ship_on_chain
    assert visible.character_on_chain
  end

  test "bump_stats/2 increments counters" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 4321, name: "Counter"})

    assert {1, nil} = Accounts.bump_stats(character.id, login_count: 1, systems_visited: 2)
    assert {1, nil} = Accounts.bump_stats(character, login_count: 1)
    assert {0, nil} = Accounts.bump_stats(character.id, login_count: 0)

    reloaded = Accounts.get_character(character.id)
    assert reloaded.login_count == 2
    assert reloaded.systems_visited == 2
  end

  test "admin_grant?/2 mirrors official Tripwire corp roles" do
    assert Accounts.admin_grant?(["Director"], [])
    assert Accounts.admin_grant?(["CEO"], [])
    assert Accounts.admin_grant?([], ["Tripwire Admin"])
    refute Accounts.admin_grant?(["Member"], [])
    refute Accounts.admin_grant?([], [])
  end

  test "attrs_from_ueberauth/1 builds attributes from an auth struct" do
    auth = %Ueberauth.Auth{
      uid: 9876,
      info: %Ueberauth.Auth.Info{name: "Daimian Mercer"},
      credentials: %Ueberauth.Auth.Credentials{
        refresh_token: "rt",
        scopes: ["scope-a"]
      }
    }

    attrs = Accounts.attrs_from_ueberauth(auth)

    assert attrs.eve_id == 9876
    assert attrs.name == "Daimian Mercer"
    assert attrs.refresh_token == "rt"
    assert attrs.scopes == ["scope-a"]
  end

  test "admin_exists?/0 ignores the demo character" do
    refute Accounts.admin_exists?()

    {:ok, _demo} =
      Accounts.upsert_character(%{
        eve_id: Tripwire.Demo.character_eve_id(),
        name: Tripwire.Demo.character_name(),
        is_admin: true
      })

    refute Accounts.admin_exists?()

    {:ok, _real} = Accounts.upsert_character(%{eve_id: 5555, name: "Real", is_admin: true})
    assert Accounts.admin_exists?()
  end

  test "claim_admin/1 promotes the first character and then refuses" do
    {:ok, character} = Accounts.upsert_character(@valid_attrs)
    refute Accounts.admin_exists?()

    assert {:ok, admin} = Accounts.claim_admin(character)
    assert admin.is_admin
    assert Accounts.admin_exists?()

    {:ok, other} = Accounts.upsert_character(%{eve_id: 6789, name: "Other"})
    assert {:error, :admin_exists} = Accounts.claim_admin(other)
    refute Accounts.get_character(other.id).is_admin
  end

  test "claim_admin/1 leaves existing admins untouched" do
    {:ok, character} = Accounts.upsert_character(%{eve_id: 1111, name: "Admin", is_admin: true})

    assert {:ok, ^character} = Accounts.claim_admin(character)
  end
end
