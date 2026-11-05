defmodule ExcessibilityStorybook.Contrast do
  @moduledoc """
  What a foreground/background pair is good for, under WCAG 2 and APCA.

  APCA tiers are the "Bronze simple mode" levels from the APCA docs: a minimum Lc
  for a kind of use, with the smallest font size/weight that use allows. They
  answer "how big does text in these colors need to be", which WCAG 2's two
  thresholds can't.
  """

  alias ExcessibilityStorybook.Color

  @tiers [
    %{min_lc: 90, use: "Any text, including long body copy", min_font: "14px+"},
    %{
      min_lc: 75,
      use: "Body text",
      min_font: "18px regular, 16px medium or 14px bold"
    },
    %{
      min_lc: 60,
      use: "Short text: labels, buttons, captions",
      min_font: "24px regular or 16px bold"
    },
    %{
      min_lc: 45,
      use: "Headlines and detailed icons",
      min_font: "36px regular or 24px bold"
    },
    %{
      min_lc: 30,
      use: "Placeholder or disabled text, solid icons",
      min_font: "never for content you need read"
    },
    %{min_lc: 15, use: "Decorative dividers and outlines only", min_font: "no text"},
    %{min_lc: 0, use: "Not reliably distinguishable", min_font: "no text"}
  ]

  def tiers, do: @tiers

  @spec assess(Color.rgb(), Color.rgb()) :: map()
  def assess(fg, bg) do
    ratio = Color.wcag_ratio(fg, bg)
    lc = Color.apca_lc(fg, bg)

    %{
      ratio: ratio,
      lc: lc,
      wcag: %{text: ratio >= 4.5, large_text: ratio >= 3.0, non_text: ratio >= 3.0},
      apca_tier: Enum.find(@tiers, &(abs(lc) >= &1.min_lc))
    }
  end

  @doc "`{foreground, background}` name pairs where `X-content` is meant to sit on `X` (base-content sits on every base-N)."
  def intended_pairs(tokens) do
    names = MapSet.new(tokens, & &1.name)

    for %{name: fg} <- tokens,
        String.ends_with?(fg, "-content"),
        prefix = String.trim_trailing(fg, "-content"),
        %{name: bg} <- tokens,
        bg == prefix or (String.starts_with?(bg, prefix <> "-") and bg != fg),
        MapSet.member?(names, bg) do
      {fg, bg}
    end
  end
end
