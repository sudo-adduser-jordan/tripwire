defmodule Tripwire.EveImages do
  @moduledoc """
  URL builders for the official EVE image server (`images.evetech.net`).

  NPC faction logos live in the `corporations` category under their
  faction id. Requested sizes must be powers of two between 32 and 1024.
  """

  @base "https://images.evetech.net"

  @faction_names %{
    500001 => "Caldari State",
    500002 => "Minmatar Republic",
    500003 => "Amarr Empire",
    500004 => "Gallente Federation",
    500005 => "Jove Empire",
    500006 => "CONCORD Assembly",
    500007 => "Ammatar Mandate",
    500008 => "Khanid Kingdom",
    500009 => "The Syndicate",
    500010 => "Guristas Pirates",
    500011 => "Angel Cartel",
    500012 => "Blood Raider Covenant",
    500013 => "EverMore",
    500014 => "ORE",
    500015 => "Thukker Tribe",
    500016 => "Servant Sisters of EVE",
    500017 => "The Society of Conscious Thought",
    500018 => "Mordu's Legion Command",
    500019 => "Sansha's Nation",
    500020 => "Serpentis",
    500021 => "Unknown",
    500024 => "Drifters",
    500025 => "Rogue Drones",
    500026 => "Triglavian Collective",
    500027 => "EDENCOM",
    500028 => "Association for Interdisciplinary Research",
    500029 => "Deathless Circle"
  }

  def alliance_logo(alliance_id, size \\ 64),
    do: "#{@base}/alliances/#{alliance_id}/logo?size=#{size}"

  def corporation_logo(corporation_id, size \\ 64),
    do: "#{@base}/corporations/#{corporation_id}/logo?size=#{size}"

  def faction_logo(faction_id, size \\ 64),
    do: "#{@base}/corporations/#{faction_id}/logo?size=#{size}"

  def character_portrait(character_id, size \\ 64),
    do: "#{@base}/characters/#{character_id}/portrait?size=#{size}"

  def type_icon(type_id, size \\ 64),
    do: "#{@base}/types/#{type_id}/icon?size=#{size}"

  def type_render(type_id, size \\ 64),
    do: "#{@base}/types/#{type_id}/render?size=#{size}"

  def faction_name(faction_id), do: Map.get(@faction_names, faction_id, "Faction #{faction_id}")

  def faction_ids, do: Map.keys(@faction_names)
end
