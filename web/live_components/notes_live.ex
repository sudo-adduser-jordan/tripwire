defmodule TripwireWeb.LiveComponents.NotesLive do
  use TripwireWeb, :live_component

  alias Tripwire.Mapping

  def update(assigns, socket) do
    comments =
      case {Map.get(assigns, :comments), Map.get(assigns, :selected_system_id)} do
        {comments, _} when is_list(comments) -> comments
        {_, nil} -> []
        {_, system_id} -> Mapping.list_comments(system_id)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:comments, comments)
     |> assign_new(:comment_body, fn -> "" end)}
  end

  def handle_event("comment-submit", params, socket) do
    body = params |> Map.get("comment", "") |> to_string() |> String.trim()

    with system_id when not is_nil(system_id) <- socket.assigns.selected_system_id,
         system when not is_nil(system) <- Mapping.get_system(system_id),
         true <- body != "",
         {:ok, _} <- Mapping.create_comment(system, %{body: body}, socket.assigns.character) do
      send(self(), {:comments_updated, system_id})

      {:noreply,
       socket
       |> assign(:comment_body, "")
       |> assign(:comments, Mapping.list_comments(system_id))}
    else
      nil -> {:noreply, put_flash(socket, :error, "Select a system first")}
      false -> {:noreply, put_flash(socket, :error, "Comment cannot be empty")}
      {:error, changeset} -> {:noreply, put_flash(socket, :error, changeset_errors(changeset))}
    end
  end

  def handle_event("comment-delete", %{"id" => id}, socket) do
    comment = Mapping.get_comment!(id)
    {:ok, _} = Mapping.delete_comment(comment)
    send(self(), {:comments_updated, comment.map_system_id})
    {:noreply, assign(socket, :comments, Mapping.list_comments(comment.map_system_id))}
  end

  def render(assigns) do
    ~H"""
    <div id="notes" class="grid-stack-item" gs-w="6" gs-h="6" gs-x="6" gs-y="0" tabindex="0">
      <div class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden">
        <ul class="list rounded-box shadow-md shrink-0">
          <li class="list-row h-fit items-center gap-1 p-1">
            <p class="px-1 text-lg font-semibold">Notes</p>
            <span class="text-xs opacity-60">{length(@comments)} notes</span>
            <span
              :if={Map.get(assigns, :selected_system_name)}
              class="badge badge-primary badge-sm ml-auto"
            >
              {Map.get(assigns, :selected_system_name)}
            </span>
          </li>
          <li>
            <form
              phx-submit="comment-submit"
              phx-target={@myself}
              class="flex gap-2 p-2"
            >
              <textarea
                name="comment"
                class="textarea textarea-sm w-full resize-y"
                rows="2"
                placeholder="Add a note for the selected system"
                autocomplete="off"
              >{@comment_body}</textarea>
              <button type="submit" class="btn btn-primary btn-sm">
                <.icon name="hero-plus" class="size-4" />
              </button>
            </form>
          </li>
        </ul>
        <div class="min-h-0 w-full flex-1 overflow-y-auto p-3 text-sm leading-6 sm:p-4">
          <div :if={@selected_system_id == nil} class="opacity-70">
            <h3 class="font-bold text-base">Welcome to zTripwire</h3>
            <p class="mt-1">Select a system to read and write notes.</p>
            <ol class="list-decimal list-inside mt-3 space-y-1.5 opacity-90">
              <li>
                <span class="font-semibold">Log in with EVE SSO</span> to create your personal map.
              </li>
              <li>
                <span class="font-semibold">Paste probe results</span>
                into the Signatures widget, then select a system to file them under.
              </li>
              <li>
                Manage signatures with delete and <span class="font-semibold">undo / redo</span>.
              </li>
              <li>
                <span class="font-semibold">Drag systems</span>
                on the map to arrange your chain; tracked character jumps add systems and links automatically.
              </li>
              <li>
                Open <span class="font-semibold">Settings</span> to pick a theme and tune widgets.
              </li>
            </ol>
          </div>
          <div
            :for={comment <- @comments}
            id={"comment-#{comment.id}"}
            class="mb-2 rounded bg-base-200/50 p-2"
          >
            <p class="whitespace-pre-wrap">{comment.body}</p>
            <div class="mt-1 flex items-center justify-between text-xs opacity-60">
              <span>{comment.character && comment.character.name}</span>
              <button
                class="btn btn-ghost btn-xs"
                phx-click="comment-delete"
                phx-value-id={comment.id}
                phx-target={@myself}
                data-confirm="Delete this note?"
              >
                <.icon name="hero-trash" class="size-3" />
              </button>
            </div>
          </div>
          <p :if={@selected_system_id != nil and @comments == []} class="opacity-50">
            No notes yet for this system.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp changeset_errors(changeset) do
    changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
  end
end
