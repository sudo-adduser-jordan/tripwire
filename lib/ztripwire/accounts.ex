defmodule Ztripwire.Accounts do
  import Ecto.Query

  alias Ztripwire.Accounts.Character
  alias Ztripwire.Masks.MaskMembership
  alias Ztripwire.Repo

  def get_character(id), do: Repo.get(Character, id)

  def delete_character(%Character{} = character), do: Repo.delete(character)

  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  def clear_refresh_token(eve_id) do
    case get_character_by_eve_id(eve_id) do
      %Character{} = character ->
        character
        |> Character.changeset(%{refresh_token: nil})
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

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
  @admin_titles ["Ztripwire Admin"]

  def admin_grant?(roles, titles) when is_list(roles) and is_list(titles) do
    Enum.any?(roles, &(&1 in @admin_roles)) or Enum.any?(titles, &(&1 in @admin_titles))
  end

  def esi_admin?(eve_id, access_token) do
    roles =
      case Ztripwire.ESI.get_character_roles(eve_id, access_token) do
        {:ok, %{"roles" => roles}} when is_list(roles) -> roles
        _ -> []
      end

    titles =
      case Ztripwire.ESI.get_character_titles(eve_id, access_token) do
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

  def admin_exists? do
    Repo.exists?(
      from(c in Character,
        where: c.is_admin == true and c.eve_id != ^Ztripwire.Demo.character_eve_id()
      )
    )
  end

  def claim_admin(%Character{is_admin: true} = character), do: {:ok, character}

  def claim_admin(%Character{} = character) do
    if admin_exists?() do
      {:error, :admin_exists}
    else
      update_character(character, %{is_admin: true})
    end
  end

  def branding do
    query =
      from(c in Character,
        where: c.is_admin == true and not is_nil(c.corporation_id),
        order_by: [asc: c.id],
        limit: 1
      )

    case Repo.one(query) do
      %Character{corporation_id: id, corporation_name: corp_name, name: char_name}
      when is_integer(id) ->
        %{
          corporation_id: id,
          name: corp_name || char_name,
          image_url: Ztripwire.EveImages.corporation_logo(id, 64)
        }

      _ ->
        nil
    end
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
