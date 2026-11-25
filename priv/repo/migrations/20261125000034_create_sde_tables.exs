defmodule Tripwire.Repo.Migrations.CreateSdeTables do
  use Ecto.Migration

  def change do
    create table(:sde_version, primary_key: false) do
      add :id, :integer, primary_key: true
      add :build_number, :integer
      add :release_date, :string
      add :synced_at, :utc_datetime
    end

    create table(:sde_regions, primary_key: false) do
      add :region_id, :integer, primary_key: true
      add :name, :string, null: false
      add :faction_id, :integer
    end

    create table(:sde_constellations, primary_key: false) do
      add :constellation_id, :integer, primary_key: true
      add :region_id, :integer
      add :name, :string, null: false
      add :faction_id, :integer
      add :wormhole_class_id, :integer
    end

    create table(:sde_systems, primary_key: false) do
      add :solar_system_id, :integer, primary_key: true
      add :name, :string, null: false
      add :security, :float
      add :security_class, :string
      add :region_id, :integer
      add :constellation_id, :integer
      add :star_class, :string
      add :temperature, :float
      add :luminosity, :float
      add :radius, :float
      add :planet_count, :integer, default: 0, null: false
      add :moon_count, :integer, default: 0, null: false
      add :belt_count, :integer, default: 0, null: false
      add :station_count, :integer, default: 0, null: false
      add :effect, :string
      add :hub, :boolean, default: false, null: false
      add :border, :boolean, default: false, null: false
      add :corridor, :boolean, default: false, null: false
      add :regional, :boolean, default: false, null: false
      add :international, :boolean, default: false, null: false
      add :position_x, :float
      add :position_y, :float
    end

    create table(:sde_gates) do
      add :from_id, :integer, null: false
      add :to_id, :integer, null: false
    end

    create table(:sde_stations, primary_key: false) do
      add :station_id, :integer, primary_key: true
      add :solar_system_id, :integer
      add :owner_id, :integer
      add :owner_name, :string
      add :operation, :string
      add :type_id, :integer
      add :type_name, :string
      add :services, {:array, :text}, default: []
    end

    create table(:sde_types, primary_key: false) do
      add :type_id, :integer, primary_key: true
      add :name, :string, null: false
      add :group_id, :integer
      add :group_name, :string
      add :category_id, :integer
      add :category_name, :string
    end

    create table(:sde_factions, primary_key: false) do
      add :faction_id, :integer, primary_key: true
      add :name, :string, null: false
    end

    create index(:sde_systems, [:name])
    create index(:sde_systems, [:region_id])
    create index(:sde_systems, [:constellation_id])
    create unique_index(:sde_gates, [:from_id, :to_id])
    create index(:sde_gates, [:from_id])
    create index(:sde_stations, [:solar_system_id])
    create index(:sde_stations, [:owner_id])
    create index(:sde_types, [:category_id])
    create index(:sde_types, [:group_id])
  end
end
