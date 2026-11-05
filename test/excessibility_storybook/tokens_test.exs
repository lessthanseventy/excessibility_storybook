defmodule ExcessibilityStorybook.TokensTest do
  use ExUnit.Case, async: true

  alias ExcessibilityStorybook.Tokens

  @css """
  @import "tailwindcss";
  @plugin "daisyui/packages/bundle/daisyui-theme" {
    name: "dark";
    --color-base-100: oklch(30% 0.016 252);
    --color-base-content: oklch(97% 0.029 256);
    --radius-box: 0.5rem;
  }
  :root {
    --color-brand: #ff0000;
    --color-glow: var(--color-brand);
  }
  @custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));
  .btn { color: red; }
  """

  test "one theme per block that declares color tokens, named by daisyUI name or selector" do
    assert [dark, root] = Tokens.parse(@css)

    assert dark.name == "dark"
    assert Enum.map(dark.tokens, & &1.name) == ["base-100", "base-content"]

    assert root.name == ":root"
    assert [%{name: "brand", rgb: {1.0, 0.0, 0.0}, css: "#ff0000"}] = root.tokens
  end

  test "tokens that can't be resolved are reported, not dropped silently" do
    [_, root] = Tokens.parse(@css)
    assert root.skipped == [{"glow", "var(--color-brand)"}]
  end
end
