defmodule ExcessibilityStorybook.ContrastTest do
  use ExUnit.Case, async: true

  alias ExcessibilityStorybook.Contrast

  @white {1.0, 1.0, 1.0}
  @black {0.0, 0.0, 0.0}

  test "black on white passes everything" do
    result = Contrast.assess(@black, @white)
    assert result.wcag == %{text: true, large_text: true, non_text: true}
    assert result.apca_tier.min_lc == 90
  end

  test "#888 on white: WCAG fails body text, APCA allows short text at 24px" do
    {:ok, grey} = ExcessibilityStorybook.Color.parse("#888")
    result = Contrast.assess(grey, @white)

    assert result.wcag == %{text: false, large_text: true, non_text: true}
    assert result.apca_tier.min_lc == 60
  end

  test "identical colors are unusable" do
    result = Contrast.assess(@white, @white)
    assert result.apca_tier.min_lc == 0
    assert result.wcag.non_text == false
  end

  test "intended pairs follow the daisyUI X / X-content convention" do
    tokens =
      for n <- ~w(base-100 base-200 base-content primary primary-content accent), do: %{name: n}

    assert Contrast.intended_pairs(tokens) == [
             {"base-content", "base-100"},
             {"base-content", "base-200"},
             {"primary-content", "primary"}
           ]
  end
end
