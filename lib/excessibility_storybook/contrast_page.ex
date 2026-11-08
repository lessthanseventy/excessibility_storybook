defmodule ExcessibilityStorybook.ContrastPage do
  @moduledoc """
  A contrast matrix for a phoenix_storybook page story, one tab per theme.

      defmodule Storybook.Accessibility.Contrast do
        use PhoenixStorybook.Story, :page

        @css "assets/css/app.css"
        def navigation, do: ExcessibilityStorybook.ContrastPage.navigation(@css)
        def render(assigns), do: ExcessibilityStorybook.ContrastPage.render(assigns, @css)
      end

  The stylesheet is re-read on every render, so editing a token shows up on reload.
  """

  use Phoenix.Component

  alias ExcessibilityStorybook.{Contrast, Tokens}

  def navigation(css_path) do
    # theme names come from the app's own stylesheet, so the atom set is bounded
    for theme <- Tokens.read!(css_path), do: {String.to_atom(theme.name), theme.name}
  end

  @doc "Renders the contrast matrix for the selected theme tab."
  @spec render(map(), Path.t()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns, css_path) do
    case Tokens.read!(css_path) do
      [] -> render_empty(assign(assigns, css_path: css_path))
      themes -> render_matrix(assigns, css_path, themes)
    end
  end

  defp render_empty(assigns) do
    ~H"""
    <div class="xsb-contrast">
      <p>
        No <code>--color-*</code> tokens found in <code>{@css_path}</code>, so there is nothing to measure.
      </p>
    </div>
    """
  end

  defp render_matrix(assigns, css_path, themes) do
    tab = to_string(assigns[:tab] || hd(themes).name)
    theme = Enum.find(themes, hd(themes), &(&1.name == tab))
    by_name = Map.new(theme.tokens, &{&1.name, &1})

    {fgs, bgs} = Enum.split_with(theme.tokens, &String.ends_with?(&1.name, "-content"))
    {fgs, bgs} = if fgs == [], do: {theme.tokens, theme.tokens}, else: {fgs, bgs}

    assigns =
      assign(assigns,
        css_path: css_path,
        theme: theme,
        pairs:
          for(
            {fg, bg} <- Contrast.intended_pairs(theme.tokens),
            do: pair_row(Map.fetch!(by_name, fg), Map.fetch!(by_name, bg))
          ),
        fgs: fgs,
        rows: for(bg <- bgs, do: {bg, for(fg <- fgs, do: {fg, Contrast.assess(fg.rgb, bg.rgb)})}),
        tiers: Contrast.tiers()
      )

    ~H"""
    <div class="xsb-contrast">
      <style>
        .xsb-contrast { font-family: Inter, ui-sans-serif, system-ui, sans-serif; line-height: 1.4; color: #1d1d1f; background: #fff; color-scheme: light; }
        .xsb-contrast table { border-collapse: collapse; margin-block: 1rem 2rem; }
        .xsb-contrast th, .xsb-contrast td { border: 1px solid #8884; padding: .4rem .6rem; text-align: left; vertical-align: top; }
        .xsb-contrast caption { text-align: left; font-weight: 600; padding-block: .5rem; }
        .xsb-swatch { padding: .5rem .75rem; border-radius: .25rem; white-space: nowrap; }
        .xsb-swatch .xsb-big { font-size: 24px; font-weight: 700; }
        .xsb-matrix td { min-width: 7rem; font-size: .8rem; }
        .xsb-fail { font-weight: 600; color: #b00020; }
        .xsb-pass { color: #116329; }
      </style>

      <p>
        Colors from <code>{@css_path}</code>, theme <strong>{@theme.name}</strong>.
        Each verdict is spelled out in words; the colored swatch is only there to look at.
      </p>

      <table :if={@pairs != []}>
        <caption>Intended pairs (each <code>-content</code> color on its own background)</caption>
        <thead>
          <tr>
            <th scope="col">Text on background</th>
            <th scope="col">Sample</th>
            <th scope="col">WCAG 2</th>
            <th scope="col">APCA</th>
            <th scope="col">Good for</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{fg, bg, r} <- @pairs}>
            <th scope="row">{fg.name} on {bg.name}</th>
            <td><.swatch fg={fg} bg={bg} /></td>
            <td>
              {ratio(r.ratio)}<br />
              <.verdict ok={r.wcag.text} label="body text" />,
              <.verdict ok={r.wcag.large_text} label="large text" />,
              <.verdict ok={r.wcag.non_text} label="UI and icons" />
            </td>
            <td>Lc {trunc(r.lc)}</td>
            <td>{r.apca_tier.use}; {r.apca_tier.min_font}</td>
          </tr>
        </tbody>
      </table>

      <table class="xsb-matrix">
        <caption>
          Every text color on every background. Cell: APCA Lc, WCAG ratio, what it's good for.
        </caption>
        <thead>
          <tr>
            <td></td>
            <th :for={fg <- @fgs} scope="col">{fg.name}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{bg, cells} <- @rows}>
            <th scope="row">on {bg.name}</th>
            <td :for={{fg, r} <- cells}>
              <div class="xsb-swatch" style={"color: #{fg.css}; background: #{bg.css}"} aria-hidden="true">Aa</div>
              Lc {trunc(r.lc)}, {ratio(r.ratio)}<br />{r.apca_tier.use}
            </td>
          </tr>
        </tbody>
      </table>

      <h2>APCA levels used</h2>
      <dl>
        <%= for t <- @tiers do %>
          <dt>Lc {t.min_lc} and up</dt>
          <dd>{t.use}. Smallest text: {t.min_font}.</dd>
        <% end %>
      </dl>

      <div :if={@theme.skipped != []}>
        <h2>Tokens not measured</h2>
        <p>These aren't literal colors, so they weren't resolved:</p>
        <ul>
          <li :for={{name, value} <- @theme.skipped}><code>--color-{name}: {value}</code></li>
        </ul>
      </div>
    </div>
    """
  end

  defp swatch(assigns) do
    ~H"""
    <div class="xsb-swatch" style={"color: #{@fg.css}; background: #{@bg.css}"} aria-hidden="true">
      Body text 16px <span class="xsb-big">Bold 24</span>
    </div>
    """
  end

  defp verdict(assigns) do
    ~H"""
    <span class={if @ok, do: "xsb-pass", else: "xsb-fail"}>{if @ok, do: "passes", else: "fails"} {@label}</span>
    """
  end

  defp pair_row(fg, bg), do: {fg, bg, Contrast.assess(fg.rgb, bg.rgb)}

  defp ratio(r), do: "#{:erlang.float_to_binary(r, decimals: 2)}:1"
end
