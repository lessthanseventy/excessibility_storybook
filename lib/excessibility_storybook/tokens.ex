defmodule ExcessibilityStorybook.Tokens do
  @moduledoc """
  Reads `--color-*` custom properties out of a stylesheet, grouped by the block
  that declares them (a daisyUI theme, `:root`, `@theme`, `[data-theme=x]`, ...).

  This is a scan of innermost `{}` blocks, not a CSS parser. `var(--x)` is followed
  through any custom property declared in the file (the last declaration wins,
  whatever its selector), then its fallback. Values that still aren't a literal
  color (e.g. `color-mix(...)`) are listed in `skipped`.
  """

  alias ExcessibilityStorybook.Color

  @block ~r/([^{};]*)\{([^{}]*)\}/
  @color_decl ~r/--color-([\w-]+)\s*:\s*([^;]+);/
  @daisy_name ~r/\bname\s*:\s*"([^"]+)"/
  @custom_prop ~r/(--[\w-]+)\s*:\s*([^;{}]+);/
  @var ~r/^var\(\s*(--[\w-]+)\s*(?:,\s*(.+))?\)$/s

  @spec parse(String.t()) :: [
          %{name: String.t(), tokens: [map()], skipped: [{String.t(), String.t()}]}
        ]
  def parse(css) do
    css = String.replace(css, ~r{/\*.*?\*/}s, "")

    props =
      Map.new(Regex.scan(@custom_prop, css, capture: :all_but_first), fn [k, v] ->
        {k, String.trim(v)}
      end)

    for [_, selector, body] <- Regex.scan(@block, css),
        decls = Regex.scan(@color_decl, body, capture: :all_but_first),
        decls != [] do
      {tokens, skipped} =
        Enum.reduce(decls, {[], []}, fn [name, value], {tokens, skipped} ->
          value = String.trim(value)

          case value |> resolve(props, 10) |> Color.parse() do
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

  defp resolve(_value, _props, 0), do: ""

  defp resolve(value, props, depth) do
    case Regex.run(@var, value) do
      [_, name] -> resolve(props[name] || "", props, depth - 1)
      [_, name, fallback] -> resolve(props[name] || String.trim(fallback), props, depth - 1)
      nil -> value
    end
  end

  defp block_name(selector, body) do
    case Regex.run(@daisy_name, body) do
      [_, name] -> name
      nil -> String.trim(selector)
    end
  end
end
