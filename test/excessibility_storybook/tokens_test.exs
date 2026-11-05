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
    --color-haze: color-mix(in oklab, red, blue);
  }
  @custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));
  .btn { color: red; }
  """

  test "one theme per block that declares color tokens, named by daisyUI name or selector" do
    assert [dark, root] = Tokens.parse(@css)

    assert dark.name == "dark"
    assert Enum.map(dark.tokens, & &1.name) == ["base-100", "base-content"]

    assert root.name == ":root"

    assert [%{name: "brand", rgb: {1.0, 0.0, 0.0}}, %{name: "glow", rgb: {1.0, 0.0, 0.0}}] =
             root.tokens
  end

  test "tokens that can't be resolved are reported, not dropped silently" do
    [_, root] = Tokens.parse(@css)
    assert root.skipped == [{"haze", "color-mix(in oklab, red, blue)"}]
  end

  test "var() is followed through any custom property in the file, keeping the written value" do
    css = """
    :root { --palette-blue-500: #1e66f5; --palette-white: var(--palette-base, #fff); }
    @plugin "daisyui-theme" {
      name: "FC";
      --color-primary: var(--palette-blue-500);
      --color-primary-content: var( --palette-white );
      --color-loop: var(--color-loop);
    }
    """

    [fc] = Tokens.parse(css)

    assert [
             %{name: "primary", css: "var(--palette-blue-500)", rgb: {_, _, _}},
             %{name: "primary-content", rgb: {1.0, 1.0, 1.0}}
           ] = fc.tokens

    assert fc.skipped == [{"loop", "var(--color-loop)"}]
  end
end
