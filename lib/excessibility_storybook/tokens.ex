defmodule ExcessibilityStorybook.Tokens do
  @moduledoc """
  Reads `--color-*` custom properties out of a stylesheet, grouped by the block
  that declares them (a daisyUI theme, `:root`, `@theme`, `[data-theme=x]`, ...).

  This is a scan of innermost `{}` blocks, not a CSS parser. `var(--x)` is followed
  through the custom properties of the same block first, then any declared in the
  file (the last declaration wins, whatever its selector), then its fallback. Values
  that still aren't a literal color (e.g. `color-mix(...)`) are listed in `skipped`.

  When two blocks share a name, the ones inside an at-rule are named with it, e.g.
  `:root @media (prefers-color-scheme: dark)`.
  """

  alias ExcessibilityStorybook.Color

  @block ~r/([^{};]*)\{([^{}]*)\}/
  @color_decl ~r/--color-([\w-]+)\s*:\s*([^;{}]+)(?:;|$|(?=\}))/
  @daisy_name ~r/(?:^|[;\s])name\s*:\s*["']([^"']+)["']/
  @custom_prop ~r/(--[\w-]+)\s*:\s*([^;{}]+)(?:;|$|(?=\}))/
  @var ~r/^var\(\s*(--[\w-]+)\s*(?:,\s*(.+))?\)$/s

  @doc "Groups the `--color-*` declarations of `css` by block, resolving `var()` references."
  @spec parse(String.t()) :: [
          %{name: String.t(), tokens: [map()], skipped: [{String.t(), String.t()}]}
        ]
  def parse(css) do
    css = String.replace(css, ~r{/\*.*?\*/}s, "")
    props = custom_props(css)

    blocks =
      for [{start, _}, {sel_at, sel_len}, {body_at, body_len}] <-
            Regex.scan(@block, css, return: :index),
          body = binary_part(css, body_at, body_len),
          decls = Regex.scan(@color_decl, body, capture: :all_but_first),
          decls != [] do
        selector = binary_part(css, sel_at, sel_len)
        {block_name(selector, body), body, decls, wrappers(css, start)}
      end

    counts = Enum.frequencies_by(blocks, &elem(&1, 0))

    for {name, body, decls, wrappers} <- blocks do
      props = Map.merge(props, custom_props(body))

      {tokens, skipped} =
        Enum.reduce(decls, {[], []}, fn [name, value], {tokens, skipped} ->
          value = String.trim(value)

          case value |> resolve(props, 10) |> Color.parse() do
            {:ok, rgb} -> {[%{name: name, css: value, rgb: rgb} | tokens], skipped}
            :error -> {tokens, [{name, value} | skipped]}
          end
        end)

      %{
        name:
          if(counts[name] > 1 and wrappers != [],
            do: Enum.join([name | wrappers], " "),
            else: name
          ),
        tokens: Enum.reverse(tokens),
        skipped: Enum.reverse(skipped)
      }
    end
  end

  @spec read!(Path.t()) :: [map()]
  def read!(path), do: path |> File.read!() |> parse()

  defp custom_props(text) do
    Map.new(Regex.scan(@custom_prop, text, capture: :all_but_first), fn [k, v] ->
      {k, String.trim(v)}
    end)
  end

  # the at-rules still open where the block starts, outermost first
  defp wrappers(css, offset) do
    ~r/([^{}]*)([{}])/
    |> Regex.scan(binary_part(css, 0, offset))
    |> Enum.reduce([], fn
      [_, prelude, "{"], open ->
        [prelude |> String.split(";") |> List.last() |> String.trim() | open]

      [_, _, "}"], open ->
        Enum.drop(open, 1)
    end)
    |> Enum.reverse()
    |> Enum.filter(&String.starts_with?(&1, "@"))
  end

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
