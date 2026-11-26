defmodule Ztripwire.Layouts.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  schema "layouts" do
    field :name, :string
    field :widgets, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:name, :widgets])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :widgets])
    |> validate_length(:name, min: 1, max: 40)
    |> unique_constraint(:name)
    |> validate_change(:widgets, fn :widgets, widgets ->
      if Ztripwire.Layouts.valid_widgets?(widgets),
        do: [],
        else: [widgets: "is not a valid widget arrangement"]
    end)
  end
end
