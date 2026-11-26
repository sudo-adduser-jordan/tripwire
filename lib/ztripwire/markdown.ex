defmodule Ztripwire.Markdown do
  def to_html(text) do
    text
    |> to_string()
    |> String.trim()
    |> case do
      "" -> ""
      body -> render_blocks(body)
    end
  end

  defp render_blocks(body) do
    {body, fenced} = extract_fenced(body)

    body
    |> String.split("\n")
    |> group_blocks()
    |> Enum.map_join("", &render_block/1)
    |> restore_fenced(fenced)
  end

  defp extract_fenced(body) do
    Regex.scan(~r/```(\w*)\n?(.*?)```/s, body)
    |> Enum.with_index()
    |> Enum.reduce({body, %{}}, fn {[full, _lang, code], i}, {text, acc} ->
      token = "\0F#{i}\0"

      if String.contains?(text, full) do
        {String.replace(text, full, token, global: false), Map.put(acc, token, escape(code))}
      else
        {text, acc}
      end
    end)
  end

  defp group_blocks(lines) do
    lines
    |> Enum.map(&classify_line/1)
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.reject(fn [head | _] -> elem(head, 0) == :blank end)
  end

  defp classify_line(""), do: {:blank, ""}
  defp classify_line("\0F" <> _ = line), do: {:fence, line}
  defp classify_line("> " <> rest), do: {:quote, rest}
  defp classify_line(">" <> rest), do: {:quote, rest}

  defp classify_line(line) do
    cond do
      match = Regex.run(~r/^(\#{1,6})\s+(.*)$/, line) ->
        [_, hashes, rest] = match
        {:header, String.length(hashes), rest}

      Regex.match?(~r/^\s*([-*+]|\d+\.)\s+\S/, line) ->
        {:list, line}

      true ->
        {:text, line}
    end
  end

  defp render_block([{:fence, line} | _]) do
    line
  end

  defp render_block([{:header, _, _} | _] = items) do
    Enum.map_join(items, "", fn {:header, level, text} ->
      "<h#{level}>#{inline(text)}</h#{level}>"
    end)
  end

  defp render_block([{:quote, _} | _] = items) do
    inner = Enum.map_join(items, "<br>", fn {_, line} -> inline(line) end)
    "<blockquote>#{inner}</blockquote>"
  end

  defp render_block([{:list, _} | _] = items) do
    tag = if ordered?(items), do: "ol", else: "ul"

    inner =
      Enum.map_join(items, "", fn {_, line} ->
        content = Regex.replace(~r/^\s*([-*+]|\d+\.)\s+/, line, "")
        "<li>#{inline(content)}</li>"
      end)

    "<#{tag}>#{inner}</#{tag}>"
  end

  defp render_block(items) do
    inner = Enum.map_join(items, "<br>", fn {_, line} -> inline(line) end)
    "<p>#{inner}</p>"
  end

  defp ordered?(items) do
    Enum.all?(items, fn {_, line} -> Regex.match?(~r/^\s*\d+\.\s/, line) end)
  end

  defp restore_fenced(html, fenced) do
    Regex.replace(~r/\0F(\d+)\0/, html, fn _, i ->
      code = fenced |> Map.fetch!("\0F#{i}\0") |> String.trim_trailing("\n")
      "<pre><code>#{code}</code></pre>"
    end)
  end

  defp inline(line) do
    {text, store} = extract_tokens(escape(line))

    text
    |> bold_italic()
    |> bold()
    |> underline()
    |> strike()
    |> italic()
    |> restore_tokens(store)
    |> restore_code_tags(store)
  end

  defp escape(text) do
    text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  defp extract_tokens(text) do
    {text, kbds} = extract_kbd(text)
    {text, links} = extract_md_links(text)
    {text, autos} = extract_autolinks(text)
    {text, codes} = extract_inline_code(text)
    {text, %{kbds: kbds, links: links, autos: autos, codes: codes}}
  end

  defp extract_kbd(text) do
    Regex.scan(~r/&lt;kbd&gt;(.*?)&lt;\/kbd&gt;/si, text)
    |> Enum.reduce({text, %{}}, fn [full, keys], {t, acc} ->
      token = "\0K#{map_size(acc)}\0"
      html = ~s(<kbd class="kbd kbd-sm">#{keys}</kbd>)
      {String.replace(t, full, token, global: false), Map.put(acc, token, html)}
    end)
  end

  defp extract_md_links(text) do
    Regex.scan(~r/\[([^\]]+)\]\((https?:[^)\s]+)\)/, text)
    |> Enum.reduce({text, %{}}, fn [full, label, url], {t, acc} ->
      token = "\0L#{map_size(acc)}\0"

      html =
        ~s(<a href="#{url}" rel="noopener noreferrer" target="_blank">#{label}</a>)

      {String.replace(t, full, token, global: false), Map.put(acc, token, html)}
    end)
  end

  defp extract_autolinks(text) do
    Regex.scan(~r/(?<![\"'=])https?:\/\/[^\s<]+/, text)
    |> Enum.reduce({text, %{}}, fn [url], {t, acc} ->
      {clean, trail} = split_trailing_punct(url)
      token = "\0A#{map_size(acc)}\0"

      html =
        ~s(<a href="#{clean}" rel="noopener noreferrer" target="_blank">#{clean}</a>) <> trail

      {String.replace(t, url, token, global: false), Map.put(acc, token, html)}
    end)
  end

  defp split_trailing_punct(url) do
    trail =
      url
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.take_while(&(&1 in [".", ",", ";", ":", "!", "?", ")"]))
      |> Enum.join()

    {String.trim_trailing(url, trail), trail}
  end

  defp extract_inline_code(text) do
    Regex.scan(~r/`([^`\n]+)`/, text)
    |> Enum.reduce({text, %{}}, fn [full, code], {t, acc} ->
      token = "\0C#{map_size(acc)}\0"
      {String.replace(t, full, token, global: false), Map.put(acc, token, code)}
    end)
  end

  defp bold_italic(text) do
    Regex.replace(~r/\*\*\*(.+?)\*\*\*/s, text, "<strong><em>\\1</em></strong>")
  end

  defp bold(text) do
    Regex.replace(~r/\*\*(.+?)\*\*/s, text, "<strong>\\1</strong>")
  end

  defp underline(text) do
    Regex.replace(~r/__(.+?)__/s, text, "<u>\\1</u>")
  end

  defp strike(text) do
    Regex.replace(~r/~~(.+?)~~/s, text, "<del>\\1</del>")
  end

  defp italic(text) do
    text
    |> String.replace(~r/\*([^*\n]+)\*/, "<em>\\1</em>")
    |> String.replace(~r/_([^_\n]+)_/, "<em>\\1</em>")
  end

  defp restore_tokens(text, %{kbds: kbds, links: links, autos: autos}) do
    store = Map.merge(kbds, links) |> Map.merge(autos)

    Regex.replace(~r/\0[KLA](\d+)\0/, text, fn token, _ ->
      case Map.fetch(store, token) do
        {:ok, html} -> html
        :error -> token
      end
    end)
  end

  defp restore_code_tags(text, %{codes: codes}) do
    Regex.replace(~r/\0C(\d+)\0/, text, fn token, _ ->
      case Map.fetch(codes, token) do
        {:ok, code} -> "<code>#{code}</code>"
        :error -> token
      end
    end)
  end
end
