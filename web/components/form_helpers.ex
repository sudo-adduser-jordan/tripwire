defmodule ZtripwireWeb.FormHelpers do
  def present(nil), do: nil
  def present(""), do: nil

  def present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  def present(value), do: value

  def changeset_errors(changeset) do
    Enum.map(changeset.errors, fn {field, {message, _}} -> "#{field} #{message}" end)
  end

  def changeset_message(changeset) do
    changeset |> changeset_errors() |> Enum.join(", ")
  end
end
