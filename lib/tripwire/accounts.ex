defmodule Tripwire.Accounts do
  import Ecto.Query

  alias Tripwire.Accounts.Character
  alias Tripwire.Masks.MaskMembership
  alias Tripwire.Repo

  def get_character(id), do: Repo.get(Character, id)

  def delete_character(%Character{} = character), do: Repo.delete(character)

  def list_characters, do: Repo.all(Character)

  def get_character_by_eve_id(eve_id) do
    Repo.one(from(c in Character, where: c.eve_id == ^eve_id))
  end

  def get_character_by_name(name) when is_binary(name) do
    Repo.one(from(c in Character, where: c.name == ^name))
  end

  def bump_stats(%Character{id: id}, inc), do: bump_stats(id, inc)

  def bump_stats(id, inc) when is_integer(id) and is_list(inc) do
    case Enum.reject(inc, fn {_field, count} -> count == 0 end) do
      [] -> {0, nil}
      filtered -> Repo.update_all(from(c in Character, where: c.id == ^id), inc: filtered)
    end
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

  @admin_roles ~w(CEO Director)
  @admin_titles ["Tripwire Admin"]

  @doc """
  Returns true when ESI corp roles/titles grant Tripwire admin.
  Mirrors official Tripwire: CEO, Director, or Tripwire Admin.
  """
  def admin_grant?(roles, titles) when is_list(roles) and is_list(titles) do
    Enum.any?(roles, &(&1 in @admin_roles)) or Enum.any?(titles, &(&1 in @admin_titles))
  end

  @doc """
  Checks ESI for admin corp roles/titles. Returns `{:ok, boolean}` and
  never fails login — ESI errors resolve to `{:ok, false}`.
  """
  def esi_admin?(eve_id, access_token) do
    roles =
      case Tripwire.ESI.get_character_roles(eve_id, access_token) do
        {:ok, %{"roles" => roles}} when is_list(roles) -> roles
        _ -> []
      end

    titles =
      case Tripwire.ESI.get_character_titles(eve_id, access_token) do
        {:ok, titles} when is_list(titles) -> titles
        _ -> []
      end

    {:ok, admin_grant?(roles, titles)}
  rescue
    _ -> {:ok, false}
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
