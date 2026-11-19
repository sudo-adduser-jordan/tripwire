defmodule TripwireWeb.CharacterVisibilityComponents do
  use Phoenix.Component

  import TripwireWeb.IconComponent

  alias Tripwire.EveImages

  @doc """

  Renders the ship toggle for a character.

  The button shows the character's current ship render when the character is the
  logged in one and the ship type is known, and a neutral cube icon otherwise.
  Each click flips whether the ship is drawn on chain; hidden state is dimmed.

  ## Examples

      <.character_ship_toggle character={character} size="lg" />

  """

  attr :character, :map, required: true
  attr :current_character, :any, default: nil
  attr :current_ship_type_id, :any, default: nil
  attr :size, :string, default: "sm", values: ["sm", "lg"]

  def character_ship_toggle(assigns) do
    assigns =
      assign(assigns,
        ship_img:
          ship_render(
            assigns.character,
            assigns[:current_character],
            assigns[:current_ship_type_id]
          ),
        hidden?: !assigns.character.ship_on_chain,
        button_class: ship_button_class(assigns.size),
        image_class: ship_image_class(assigns.size)
      )

    ~H"""
    <button
      type="button"
      phx-click="toggle-ship-visibility"
      phx-value-id={@character.id}
      title={ship_title(@character)}
      class={@button_class}
    >
      <img
        :if={@ship_img}
        src={@ship_img}
        alt=""
        loading="lazy"
        class={[@image_class, @hidden? && "opacity-40"]}
        onerror="this.onerror=null;this.style.display='none'"
      />
      <.icon
        :if={!@ship_img}
        name="hero-cube"
        class={[@image_class, @hidden? && "opacity-40"]}
      />
    </button>
    """
  end

  @doc """

  Renders the character portrait as the character visibility toggle.

  Clicking the portrait hides or shows the character on chain; hidden state is
  dimmed and the avatar dot still marks the logged in character.

  ## Examples

      <.character_portrait_toggle character={character} current_character={current} size="lg" />

  """

  attr :character, :map, required: true
  attr :current_character, :any, default: nil
  attr :size, :string, default: "sm", values: ["sm", "lg"]

  def character_portrait_toggle(assigns) do
    assigns =
      assign(assigns,
        hidden?: !assigns.character.character_on_chain,
        dot: dot(assigns.character, assigns[:current_character]),
        avatar_class: avatar_class(assigns.size)
      )

    ~H"""
    <button
      type="button"
      phx-click="toggle-character-visibility"
      phx-value-id={@character.id}
      title={character_title(@character)}
      class="shrink-0 hover:cursor-pointer"
    >
      <div class={["avatar", @dot]}>
        <div class={@avatar_class}>
          <img
            src={portrait(@character)}
            alt=""
            loading="lazy"
            class={@hidden? && "opacity-40"}
            onerror="this.onerror=null;this.src='/images/alliance-default.png'"
          />
        </div>
      </div>
    </button>
    """
  end

  defp ship_render(%{eve_id: eve_id}, %{eve_id: current_eve_id}, ship_type_id)
       when eve_id == current_eve_id and is_integer(ship_type_id) and ship_type_id > 0,
       do: EveImages.type_render(ship_type_id, 64)

  defp ship_render(_, _, _), do: nil

  defp portrait(%{eve_id: eve_id}) when is_integer(eve_id) and eve_id > 0,
    do: EveImages.character_portrait(eve_id, 64)

  defp portrait(_), do: "/images/alliance-default.png"

  defp avatar_class("lg"), do: "w-12 rounded-xl"
  defp avatar_class(_), do: "w-8 rounded-lg"

  defp ship_button_class("lg"),
    do:
      "flex size-12 shrink-0 items-center justify-center rounded-xl p-0 hover:cursor-pointer hover:bg-base-300"

  defp ship_button_class(_), do: "btn btn-ghost btn-xs shrink-0 p-1"

  defp ship_image_class("lg"), do: "size-10 object-contain"
  defp ship_image_class(_), do: "size-4"

  defp dot(%{id: id}, %{id: other_id}) when id == other_id, do: "avatar-online"
  defp dot(_, _), do: "avatar-offline"

  defp ship_title(%{ship_on_chain: false, name: name}), do: "Show #{name}'s ship on chain"
  defp ship_title(%{name: name}), do: "Hide #{name}'s ship on chain"

  defp character_title(%{character_on_chain: false, name: name}),
    do: "Show #{name} on chain"

  defp character_title(%{name: name}),
    do: "Hide #{name}'s character and ship on chain"
end
