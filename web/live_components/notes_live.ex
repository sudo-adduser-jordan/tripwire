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
     |> assign_new(:comment_body, fn -> "" end)
     |> assign_new(:editing_comment_id, fn -> nil end)
     |> assign_new(:edit_body, fn -> "" end)
     |> drop_stale_edit(comments)}
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

  def handle_event("comment-edit", %{"id" => id}, socket) do
    comment = Mapping.get_comment!(id)

    {:noreply,
     socket
     |> assign(:editing_comment_id, comment.id)
     |> assign(:edit_body, comment.body)}
  end

  def handle_event("comment-edit-cancel", _params, socket) do
    {:noreply, socket |> assign(:editing_comment_id, nil) |> assign(:edit_body, "")}
  end

  def handle_event("comment-edit-submit", params, socket) do
    body = params |> Map.get("comment", "") |> to_string() |> String.trim()

    case socket.assigns.editing_comment_id do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a note to edit")}

      id ->
        comment = Mapping.get_comment!(id)

        with true <- body != "",
             {:ok, _} <- Mapping.update_comment(comment, %{body: body}, socket.assigns.character) do
          send(self(), {:comments_updated, comment.map_system_id})

          {:noreply,
           socket
           |> assign(:editing_comment_id, nil)
           |> assign(:edit_body, "")
           |> assign(:comments, Mapping.list_comments(comment.map_system_id))}
        else
          false ->
            {:noreply,
             socket |> assign(:edit_body, body) |> put_flash(:error, "Comment cannot be empty")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:edit_body, body)
             |> put_flash(:error, changeset_errors(changeset))}
        end
    end
  end

  def handle_event("comment-delete", %{"id" => id}, socket) do
    comment = Mapping.get_comment!(id)
    {:ok, _} = Mapping.delete_comment(comment, socket.assigns.character)
    send(self(), {:comments_updated, comment.map_system_id})

    socket =
      if socket.assigns[:editing_comment_id] == comment.id do
        socket |> assign(:editing_comment_id, nil) |> assign(:edit_body, "")
      else
        socket
      end

    {:noreply, assign(socket, :comments, Mapping.list_comments(comment.map_system_id))}
  end

  def render(assigns) do
    ~H"""
    <div
      id="notes"
      class="grid-stack-item"
      gs-w="6"
      gs-h="6"
      gs-x="6"
      gs-y="0"
      tabindex="0"
      phx-hook="GridWidget"
    >
      <div class="grid-stack-item-content bg-base-100/50 flex min-h-0 flex-col overflow-hidden">
        <ul class="list rounded-box shadow-md shrink-0">
          <li class="list-row h-fit items-center gap-1 p-1">
            <span class="px-1 text-xs opacity-60">{length(@comments)} notes</span>
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
              <button type="submit" class="btn btn-primary btn-sm" title="Add note">
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
            <form
              :if={@editing_comment_id == comment.id}
              phx-submit="comment-edit-submit"
              phx-target={@myself}
              class="flex flex-col gap-2"
            >
              <textarea
                name="comment"
                class="textarea textarea-sm w-full resize-y"
                rows="3"
                autocomplete="off"
              >{@edit_body}</textarea>
              <div class="flex items-center justify-end gap-1">
                <button
                  type="button"
                  id={"note-edit-cancel-#{comment.id}"}
                  class="btn btn-ghost btn-xs"
                  title="Cancel edit"
                  phx-click="comment-edit-cancel"
                  phx-target={@myself}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  id={"note-edit-save-#{comment.id}"}
                  class="btn btn-primary btn-xs"
                  title="Save note"
                >
                  Save
                </button>
              </div>
            </form>
            <div :if={@editing_comment_id != comment.id}>
              <div class="markdown space-y-1 [&_a]:underline [&_blockquote]:border-l-2 [&_blockquote]:border-base-content/40 [&_blockquote]:pl-2 [&_blockquote]:opacity-70 [&_code]:rounded [&_code]:bg-black/30 [&_code]:px-1 [&_h1]:text-lg [&_h1]:font-bold [&_h2]:text-base [&_h2]:font-bold [&_h3]:text-sm [&_h3]:font-bold [&_h4]:font-bold [&_h5]:font-bold [&_h6]:font-bold [&_ol]:list-decimal [&_ol]:pl-5 [&_pre]:overflow-x-auto [&_pre]:rounded [&_pre]:bg-black/30 [&_pre]:p-2 [&_ul]:list-disc [&_ul]:pl-5">
                {Phoenix.HTML.raw(Tripwire.Markdown.to_html(comment.body))}
              </div>
              <div class="mt-1 flex items-center justify-between text-xs opacity-60">
                <span>{comment.character && comment.character.name}</span>
                <div class="flex items-center gap-1">
                  <button
                    id={"note-copy-#{comment.id}"}
                    class="group btn btn-ghost btn-xs p-1"
                    title="Copy note"
                    phx-hook="CopyText"
                    data-copy={comment.body}
                  >
                    <.icon name="hero-clipboard" class="copy-icon size-3" />
                    <.icon name="hero-check" class="copied-icon hidden size-3 text-success" />
                  </button>
                  <button
                    id={"note-edit-#{comment.id}"}
                    class="btn btn-ghost btn-xs p-1"
                    title="Edit note"
                    phx-click="comment-edit"
                    phx-value-id={comment.id}
                    phx-target={@myself}
                  >
                    <.icon name="hero-pencil" class="size-3" />
                  </button>
                  <button
                    class="btn btn-ghost btn-xs"
                    title="Delete note"
                    phx-click="comment-delete"
                    phx-value-id={comment.id}
                    phx-target={@myself}
                    data-confirm="Delete this note?"
                  >
                    <.icon name="hero-trash" class="size-3" />
                  </button>
                </div>
              </div>
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

  defp drop_stale_edit(socket, comments) do
    case socket.assigns[:editing_comment_id] do
      nil ->
        socket

      id ->
        if Enum.any?(comments, &(&1.id == id)) do
          socket
        else
          socket |> assign(:editing_comment_id, nil) |> assign(:edit_body, "")
        end
    end
  end

  defp changeset_errors(changeset) do
    changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f} #{m}" end) |> Enum.join(", ")
  end
end
