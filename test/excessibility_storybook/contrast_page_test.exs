defmodule ExcessibilityStorybook.ContrastPageTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias ExcessibilityStorybook.ContrastPage

  @moduletag :tmp_dir

  @two_themes """
  [data-theme=light] { --color-base-100: #ffffff; --color-base-content: #000000; }
  [data-theme=dark] { --color-base-100: #000000; --color-base-content: #ffffff; --color-haze: color-mix(in oklab, red, blue); }
  """

  defp html(assigns, dir, css) do
    path = Path.join(dir, "app.css")
    File.write!(path, css)
    assigns |> Map.put(:__changed__, nil) |> ContrastPage.render(path) |> rendered_to_string()
  end

  test "renders the first theme's intended pair", %{tmp_dir: dir} do
    out = html(%{}, dir, @two_themes)

    assert out =~ "theme <strong>[data-theme=light]</strong>"
    assert out =~ "base-content on base-100"
    assert out =~ "passes body text"
  end

  test "the tab assign picks the theme and lists tokens it could not measure", %{tmp_dir: dir} do
    out = html(%{tab: "[data-theme=dark]"}, dir, @two_themes)

    assert out =~ "theme <strong>[data-theme=dark]</strong>"
    assert out =~ "Tokens not measured"
    assert out =~ "--color-haze: color-mix(in oklab, red, blue)"
  end

  # the empty state belongs to contrast_page.ex; this documents current behaviour
  test "a stylesheet with no color tokens raises", %{tmp_dir: dir} do
    assert_raise ArgumentError, fn -> html(%{}, dir, ".btn { color: red; }") end
  end
end
