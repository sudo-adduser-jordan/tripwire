defmodule Tripwire.Accounts do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Masks.MaskMembership
  alias Tripwire.Repo

  def get_character(id), do: Repo.get(Character, id)

  def list_characters, do: Repo.all(Character)

  def get_character_by_eve_id(eve_id) do
    Repo.one(from(c in Character, where: c.eve_id == ^eve_id))
  end

  def upsert_character(attrs) do
    eve_id = attrs[:eve_id] || attrs["eve_id"]

    character =
      case eve_id && get_character_by_eve_id(eve_id) do
        %Character{} = character -> character
        _ -> %Character{}
      end

    character
    |> Character.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc """
  Builds character attributes from a `Ueberauth.Auth` struct returned by the EVE SSO strategy.
  """
  def attrs_from_ueberauth(%Ueberauth.Auth{} = auth) do
    %{
      eve_id: auth.uid,
      name: auth.info.name,
      refresh_token: auth.credentials.refresh_token,
      scopes: auth.credentials.scopes || [],
      last_login_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def upsert_character_from_ueberauth(%Ueberauth.Auth{} = auth) do
    auth |> attrs_from_ueberauth() |> upsert_character()
  end

  def list_characters_for_mask(mask_id) do
    Repo.all(
      from(c in Character,
        join: m in MaskMembership,
        on: m.character_id == c.id,
        where: m.mask_id == ^mask_id
      )
    )
  end
end
