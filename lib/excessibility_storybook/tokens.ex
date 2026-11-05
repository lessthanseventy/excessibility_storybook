defmodule ExcessibilityStorybook.Tokens do
  @moduledoc """
  Reads `--color-*` custom properties out of a stylesheet, grouped by the block
  that declares them (a daisyUI theme, `:root`, `@theme`, `[data-theme=x]`, ...).

  This is a scan of innermost `{}` blocks, not a CSS parser. Values that aren't a
  literal color (e.g. `var(...)`, `color-mix(...)`) are listed in `skipped`.
  """

  alias ExcessibilityStorybook.Color

  @block ~r/([^{};]*)\{([^{}]*)\}/
  @color_decl ~r/--color-([\w-]+)\s*:\s*([^;]+);/
  @daisy_name ~r/\bname\s*:\s*"([^"]+)"/

  @spec parse(String.t()) :: [
          %{name: String.t(), tokens: [map()], skipped: [{String.t(), String.t()}]}
        ]
  def parse(css) do
    css = String.replace(css, ~r{/\*.*?\*/}s, "")

    for [_, selector, body] <- Regex.scan(@block, css),
        decls = Regex.scan(@color_decl, body, capture: :all_but_first),
        decls != [] do
      {tokens, skipped} =
        Enum.reduce(decls, {[], []}, fn [name, value], {tokens, skipped} ->
          value = String.trim(value)

          case Color.parse(value) do
            {:ok, rgb} -> {[%{name: name, css: value, rgb: rgb} | tokens], skipped}
            :error -> {tokens, [{name, value} | skipped]}
          end
        end)

      %{
        name: block_name(selector, body),
        tokens: Enum.reverse(tokens),
        skipped: Enum.reverse(skipped)
      }
    end
  end

  @spec read!(Path.t()) :: [map()]
  def read!(path), do: path |> File.read!() |> parse()

  defp block_name(selector, body) do
    case Regex.run(@daisy_name, body) do
      [_, name] -> name
      nil -> String.trim(selector)
    end
  end
end
