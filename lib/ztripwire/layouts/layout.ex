defmodule Ztripwire.Layouts.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  schema "layouts" do
    field :name, :string
    field :widgets, :map
    field :owner_character_id, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:name, :widgets, :owner_character_id])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :widgets])
    |> validate_length(:name, min: 1, max: 40)
    |> unique_constraint([:owner_character_id, :name],
      name: :layouts_owner_character_id_name_index,
      error_key: :name
    )
    |> validate_change(:widgets, fn :widgets, widgets ->
      if Ztripwire.Layouts.valid_widgets?(widgets),
        do: [],
        else: [widgets: "is not a valid widget arrangement"]
    end)
  end
end
