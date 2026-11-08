defmodule ExcessibilityStorybook.Tokens do
  @moduledoc """
  Reads `--color-*` custom properties out of a stylesheet, grouped by the block
  that declares them (a daisyUI theme, `:root`, `@theme`, `[data-theme=x]`, ...).

  This is a scan of innermost `{}` blocks, not a CSS parser. `var(--x)` is followed
  through the custom properties of the same block first, then any declared in the
  file (the last declaration wins, whatever its selector), then its fallback. Values
  that still aren't a literal color (e.g. `color-mix(...)`) are listed in `skipped`.
  A `var()` that several selectors set differently (`:root` and `.dark`, say) gives
  one theme per selector, named `@theme inline (.dark)`.

  When two blocks share a name, the ones inside an at-rule are named with it, e.g.
  `:root @media (prefers-color-scheme: dark)`; blocks still sharing a name are one theme.
  """

  alias ExcessibilityStorybook.Color

  @block ~r/([^{};]*)\{([^{}]*)\}/
  @color_decl ~r/--color-([\w-]+)\s*:\s*([^;{}]+)(?:;|$|(?=\}))/
  @daisy_name ~r/(?:^|[;\s])name\s*:\s*["']([^"']+)["']/
  @custom_prop ~r/(--[\w-]+)\s*:\s*([^;{}]+)(?:;|$|(?=\}))/
  @var ~r/^var\(\s*(--[\w-]+)\s*(?:,\s*(.+))?\)$/s
  @var_ref ~r/var\(\s*(--[\w-]+)/

  @doc "Groups the `--color-*` declarations of `css` by block, resolving `var()` references."
  @spec parse(String.t()) :: [
          %{name: String.t(), tokens: [map()], skipped: [{String.t(), String.t()}]}
        ]
  def parse(css) do
    css = String.replace(css, ~r{/\*.*?\*/}s, "")
    props = custom_props(css)

    all_blocks =
      for [{start, _}, {sel_at, sel_len}, {body_at, body_len}] <-
            Regex.scan(@block, css, return: :index) do
        body = binary_part(css, body_at, body_len)
        selector = binary_part(css, sel_at, sel_len)
        {selector, body, Regex.scan(@color_decl, body, capture: :all_but_first), start}
      end

    scopes =
      for {selector, body, _, _} <- all_blocks, do: {String.trim(selector), custom_props(body)}

    blocks =
      for {selector, body, decls, start} <- all_blocks, decls != [] do
        {block_name(selector, body), body, decls, wrappers(css, start)}
      end

    counts = Enum.frequencies_by(blocks, &elem(&1, 0))

    blocks
    |> Enum.flat_map(fn {name, body, decls, wrappers} ->
      name =
        if counts[name] > 1 and wrappers != [], do: Enum.join([name | wrappers], " "), else: name

      local = custom_props(body)

      for {suffix, scoped} <- variants(decls, local, scopes) do
        theme(name <> suffix, decls, props |> Map.merge(scoped) |> Map.merge(local))
      end
    end)
    |> merge_same_name()
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

  defp theme(name, decls, props) do
    {tokens, skipped} =
      Enum.reduce(decls, {[], []}, fn [token, value], {tokens, skipped} ->
        value = String.trim(value)

        case value |> resolve(props, 10) |> Color.parse() do
          {:ok, rgb} -> {[%{name: token, css: value, rgb: rgb} | tokens], skipped}
          :error -> {tokens, [{token, value} | skipped]}
        end
      end)

    %{name: name, tokens: Enum.reverse(tokens), skipped: Enum.reverse(skipped)}
  end

  # the selectors that set a referenced var to different values, if more than one
  defp variants(decls, local, scopes) do
    referenced =
      for [_, value] <- decls,
          [_, var] <- Regex.scan(@var_ref, value),
          not Map.has_key?(local, var),
          uniq: true,
          do: var

    declaring =
      for {selector, scoped} <- scopes,
          picked = Map.take(scoped, referenced),
          picked != %{},
          do: {selector, picked}

    case Enum.uniq_by(declaring, &elem(&1, 1)) do
      [_ | [_ | _]] = many -> for {selector, scoped} <- many, do: {" (#{selector})", scoped}
      _ -> [{"", %{}}]
    end
  end

  defp merge_same_name(themes) do
    themes
    |> Enum.reduce([], fn theme, acc ->
      case Enum.find_index(acc, &(&1.name == theme.name)) do
        nil ->
          [theme | acc]

        i ->
          List.update_at(acc, i, fn seen ->
            %{seen | tokens: seen.tokens ++ theme.tokens, skipped: seen.skipped ++ theme.skipped}
          end)
      end
    end)
    |> Enum.reverse()
  end
end
