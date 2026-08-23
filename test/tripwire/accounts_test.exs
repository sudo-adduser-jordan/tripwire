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
end
