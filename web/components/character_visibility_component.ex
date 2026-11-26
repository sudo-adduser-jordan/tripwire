defmodule ZtripwireWeb.CharacterVisibilityComponents do
  use Phoenix.Component

  import ZtripwireWeb.IconComponent

  alias Ztripwire.EveImages

  attr :character, :map, required: true
  attr :ship_type_id, :any, default: nil
  attr :size, :string, default: "sm", values: ["sm", "lg"]

  def character_ship_toggle(assigns) do
    assigns =
      assign(assigns,
        ship_img: ship_render(assigns[:ship_type_id]),
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
        onerror={ship_fallback(@ship_type_id)}
      />
      <.icon
        name="hero-cube"
        class={[@image_class, @hidden? && "opacity-40", @ship_img && "hidden"]}
      />
    </button>
    """
  end

  attr :character, :map, required: true
  attr :current_character, :any, default: nil
  attr :online, :any, default: nil
  attr :size, :string, default: "sm", values: ["sm", "lg"]

  def character_portrait_toggle(assigns) do
    assigns =
      assign(assigns,
        hidden?: !assigns.character.character_on_chain,
        dot: dot(assigns[:online], assigns.character, assigns[:current_character]),
        avatar_class: avatar_class(assigns.size)
      )

    ~H"""
    <button
      type="button"
      phx-click="toggle-character-visibility"
      phx-value-id={@character.id}
      title={character_title(@character)}
      class="pointer-events-auto shrink-0 hover:cursor-pointer"
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

  defp ship_render(ship_type_id) when is_integer(ship_type_id) and ship_type_id > 0,
    do: EveImages.type_render(ship_type_id, 64)

  defp ship_render(_), do: nil

  defp ship_fallback(ship_type_id) do
    "this.onerror=function(){this.style.display='none';" <>
      "this.nextElementSibling && this.nextElementSibling.classList.remove('hidden')};" <>
      "this.src='#{EveImages.type_icon(ship_type_id, 64)}'"
  end

  defp portrait(%{eve_id: eve_id}) when is_integer(eve_id) and eve_id > 0,
    do: EveImages.character_portrait(eve_id, 64)

  defp portrait(_), do: "/images/alliance-default.png"

  defp avatar_class("lg"), do: "w-12 rounded-xl"
  defp avatar_class(_), do: "w-8 rounded-lg"

  defp ship_button_class("lg"),
    do:
      "pointer-events-auto flex size-12 shrink-0 items-center justify-center rounded-xl p-0 hover:cursor-pointer hover:bg-base-300"

  defp ship_button_class(_),
    do:
      "pointer-events-auto flex size-8 shrink-0 items-center justify-center rounded-lg p-0 hover:cursor-pointer hover:bg-base-300"

  defp ship_image_class("lg"), do: "size-12 object-contain"
  defp ship_image_class(_), do: "size-8 object-contain"

  defp dot(_online, %{id: id}, %{id: other_id}) when id == other_id, do: "avatar-online"
  defp dot(true, _character, _current), do: "avatar-online"
  defp dot(_online, _character, _current), do: "avatar-offline"

  defp ship_title(%{ship_on_chain: false, name: name}), do: "Show #{name}'s ship on chain"
  defp ship_title(%{name: name}), do: "Hide #{name}'s ship on chain"

  defp character_title(%{character_on_chain: false, name: name}),
    do: "Show #{name} on chain"

  defp character_title(%{name: name}),
    do: "Hide #{name}'s character and ship on chain"
end
