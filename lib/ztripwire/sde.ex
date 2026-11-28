defmodule Ztripwire.Sde do
  alias Ztripwire.Repo
  alias Ztripwire.Sde.{Constellation, Region, System, Type}

  def enabled? do
    Application.get_env(:ztripwire, :sde_enabled, true)
  end

  def system(solar_system_id) when is_integer(solar_system_id) do
    if enabled?(), do: Repo.get(System, solar_system_id)
  end

  def system(_), do: nil

  def constellation(constellation_id) when is_integer(constellation_id) do
    if enabled?(), do: Repo.get(Constellation, constellation_id)
  end

  def constellation(_), do: nil

  def region(region_id) when is_integer(region_id) do
    if enabled?(), do: Repo.get(Region, region_id)
  end

  def region(_), do: nil

  def type(type_id) when is_integer(type_id) do
    if enabled?(), do: Repo.get(Type, type_id)
  end

  def type(_), do: nil

  def system_name(solar_system_id) do
    case system(solar_system_id) do
      %{name: name} -> name
      _ -> nil
    end
  end

  def constellation_name(constellation_id) do
    case constellation(constellation_id) do
      %{name: name} -> name
      _ -> nil
    end
  end

  def region_name(region_id) do
    case region(region_id) do
      %{name: name} -> name
      _ -> nil
    end
  end

  def type_name(type_id) do
    case type(type_id) do
      %{name: name} -> name
      _ -> nil
    end
  end
end
