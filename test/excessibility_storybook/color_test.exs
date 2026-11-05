defmodule ExcessibilityStorybook.ColorTest do
  use ExUnit.Case, async: true

  alias ExcessibilityStorybook.Color

  describe "parse/1" do
    test "hex, short hex, rgb()" do
      assert Color.parse("#ffffff") == {:ok, {1.0, 1.0, 1.0}}
      assert Color.parse("#000") == {:ok, {0.0, 0.0, 0.0}}
      assert Color.parse("rgb(255 0 0)") == {:ok, {1.0, 0.0, 0.0}}
    end

    test "oklch endpoints are black and white" do
      assert {:ok, white} = Color.parse("oklch(100% 0 0)")
      assert_rgb(white, {1.0, 1.0, 1.0})
      assert {:ok, black} = Color.parse("oklch(0% 0 0)")
      assert_rgb(black, {0.0, 0.0, 0.0})
    end

    test "oklch red matches CSS reference" do
      # CSS Color 4: oklch(62.8% 0.2577 29.23) is sRGB red
      assert {:ok, red} = Color.parse("oklch(62.8% 0.2577 29.23)")
      assert_rgb(red, {1.0, 0.0, 0.0}, 0.01)
    end

    test "unknown syntax is an error, not a guess" do
      assert Color.parse("var(--x)") == :error
    end
  end

  describe "wcag_ratio/2" do
    test "black on white is 21" do
      assert_in_delta Color.wcag_ratio({0.0, 0.0, 0.0}, {1.0, 1.0, 1.0}), 21.0, 0.001
    end

    test "#767676 on white is the famous 4.54" do
      {:ok, grey} = Color.parse("#767676")
      assert_in_delta Color.wcag_ratio(grey, {1.0, 1.0, 1.0}), 4.54, 0.01
    end
  end

  describe "apca_lc/2 (text, background)" do
    # reference values from the APCA README (apca-w3 0.0.98G-4g)
    test "#888 on #fff is Lc 63.06" do
      {:ok, grey} = Color.parse("#888")
      assert_in_delta Color.apca_lc(grey, {1.0, 1.0, 1.0}), 63.06, 0.05
    end

    test "#fff on #888 is Lc -68.54" do
      {:ok, grey} = Color.parse("#888")
      assert_in_delta Color.apca_lc({1.0, 1.0, 1.0}, grey), -68.54, 0.05
    end

    test "black on white is Lc 106.04" do
      assert_in_delta Color.apca_lc({0.0, 0.0, 0.0}, {1.0, 1.0, 1.0}), 106.04, 0.05
    end
  end

  defp assert_rgb({r, g, b}, {er, eg, eb}, delta \\ 0.001) do
    assert_in_delta r, er, delta
    assert_in_delta g, eg, delta
    assert_in_delta b, eb, delta
  end
end
