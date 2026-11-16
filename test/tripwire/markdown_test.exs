defmodule Tripwire.MarkdownTest do
  use ExUnit.Case, async: true

  alias Tripwire.Markdown

  test "to_html/1 renders emphasis" do
    assert Markdown.to_html("**bold**") == "<p><strong>bold</strong></p>"
    assert Markdown.to_html("***both***") == "<p><strong><em>both</em></strong></p>"
    assert Markdown.to_html("*italic*") == "<p><em>italic</em></p>"
    assert Markdown.to_html("_italic_") == "<p><em>italic</em></p>"
    assert Markdown.to_html("__underline__") == "<p><u>underline</u></p>"
    assert Markdown.to_html("~~strike~~") == "<p><del>strike</del></p>"
  end

  test "to_html/1 renders code" do
    assert Markdown.to_html("`code`") == "<p><code>code</code></p>"

    assert Markdown.to_html("```\nK162 ABC-123\n```") ==
             "<pre><code>K162 ABC-123</code></pre>"

    assert Markdown.to_html("**not `*bold*`**") ==
             "<p><strong>not <code>*bold*</code></strong></p>"
  end

  test "to_html/1 renders links" do
    assert Markdown.to_html("[EVE](https://example.com)") ==
             ~s(<p><a href="https://example.com" rel="noopener noreferrer" target="_blank">EVE</a></p>)

    assert Markdown.to_html("see https://example.com.") ==
             ~s(<p>see <a href="https://example.com" rel="noopener noreferrer" target="_blank">https://example.com</a>.</p>)
  end

  test "to_html/1 renders headers" do
    assert Markdown.to_html("# Title") == "<h1>Title</h1>"
    assert Markdown.to_html("## Sub") == "<h2>Sub</h2>"
    assert Markdown.to_html("###### Tiny") == "<h6>Tiny</h6>"
    assert Markdown.to_html("#nospace") == "<p>#nospace</p>"
    assert Markdown.to_html("####### Too many") == "<p>####### Too many</p>"
  end

  test "to_html/1 renders quotes and lists" do
    assert Markdown.to_html("> watch this") == "<blockquote>watch this</blockquote>"

    assert Markdown.to_html("- one\n- two") ==
             "<ul><li>one</li><li>two</li></ul>"

    assert Markdown.to_html("1. one\n2. two") ==
             "<ol><li>one</li><li>two</li></ol>"
  end

  test "to_html/1 renders kbd tags with the daisy component" do
    assert Markdown.to_html("<kbd>Ctrl</kbd> + <kbd>V</kbd>") ==
             ~s(<p><kbd class="kbd kbd-sm">Ctrl</kbd> + <kbd class="kbd kbd-sm">V</kbd></p>)

    assert Markdown.to_html("<kbd><script></kbd>") ==
             "<p><kbd class=\"kbd kbd-sm\">&lt;script&gt;</kbd></p>"

    assert Markdown.to_html("<kbd>**bold**</kbd>") ==
             ~s(<p><kbd class="kbd kbd-sm">**bold**</kbd></p>)
  end

  test "to_html/1 escapes hostile input" do
    assert Markdown.to_html("<script>alert(1)</script>") ==
             "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>"

    assert Markdown.to_html("[x](javascript:alert(1))") == "<p>[x](javascript:alert(1))</p>"

    assert Markdown.to_html("**<img src=x onerror=alert(1)>**") ==
             "<p><strong>&lt;img src=x onerror=alert(1)&gt;</strong></p>"
  end

  test "to_html/1 returns empty string for blank input" do
    assert Markdown.to_html("") == ""
    assert Markdown.to_html("   \n  ") == ""
    assert Markdown.to_html(nil) == ""
  end
end
