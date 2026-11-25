defmodule Tripwire.EveImages do
  @base "https://images.evetech.net"
  @unknown_character_id 1

  @faction_names %{
    500_001 => "Caldari State",
    500_002 => "Minmatar Republic",
    500_003 => "Amarr Empire",
    500_004 => "Gallente Federation",
    500_005 => "Jove Empire",
    500_006 => "CONCORD Assembly",
    500_007 => "Ammatar Mandate",
    500_008 => "Khanid Kingdom",
    500_009 => "The Syndicate",
    500_010 => "Guristas Pirates",
    500_011 => "Angel Cartel",
    500_012 => "Blood Raider Covenant",
    500_013 => "EverMore",
    500_014 => "ORE",
    500_015 => "Thukker Tribe",
    500_016 => "Servant Sisters of EVE",
    500_017 => "The Society of Conscious Thought",
    500_018 => "Mordu's Legion Command",
    500_019 => "Sansha's Nation",
    500_020 => "Serpentis",
    500_021 => "Unknown",
    500_024 => "Drifters",
    500_025 => "Rogue Drones",
    500_026 => "Triglavian Collective",
    500_027 => "EDENCOM",
    500_028 => "Association for Interdisciplinary Research",
    500_029 => "Deathless Circle"
  }

  def alliance_logo(alliance_id, size \\ 64),
    do: "#{@base}/alliances/#{alliance_id}/logo?size=#{size}"

  def corporation_logo(corporation_id, size \\ 64),
    do: "#{@base}/corporations/#{corporation_id}/logo?size=#{size}"

  def faction_logo(faction_id, size \\ 64),
    do: "#{@base}/corporations/#{faction_id}/logo?size=#{size}"

  def character_portrait(character_id, size \\ 64),
    do: "#{@base}/characters/#{character_id}/portrait?size=#{size}"

  def unknown_character_portrait(size \\ 64), do: character_portrait(@unknown_character_id, size)

  def type_icon(type_id, size \\ 64),
    do: "#{@base}/types/#{type_id}/icon?size=#{size}"

  def type_render(type_id, size \\ 64),
    do: "#{@base}/types/#{type_id}/render?size=#{size}"

  def faction_name(faction_id), do: Map.get(@faction_names, faction_id, "Faction #{faction_id}")
end
