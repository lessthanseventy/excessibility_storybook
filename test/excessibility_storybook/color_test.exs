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

  describe "parse/1 edge cases" do
    test "leading-dot numbers" do
      assert {:ok, a} = Color.parse("oklch(.5 .1 30)")
      assert {:ok, b} = Color.parse("oklch(0.5 0.1 30)")
      assert_rgb(a, b)
      assert {:ok, {r, _, _}} = Color.parse("rgb(-.5 0 0)")
      assert r == 0.0
      assert {:ok, {r, _, _}} = Color.parse("rgb(.5% 0 0)")
      assert_in_delta r, 0.005, 1.0e-9
    end

    test "unparseable numbers are an error" do
      assert Color.parse("oklch(abc .1 30)") == :error
      assert Color.parse("oklch(50% x 30)") == :error
      assert Color.parse("rgb(1 2 three)") == :error
      assert Color.parse("oklch(50% 0.1 30xyz)") == :error
    end

    test "oklch none is zero for that channel" do
      assert {:ok, a} = Color.parse("oklch(50% none 30)")
      assert {:ok, b} = Color.parse("oklch(50% 0 30)")
      assert_rgb(a, b)
      assert {:ok, c} = Color.parse("oklch(none 0 0)")
      assert_rgb(c, {0.0, 0.0, 0.0})
      assert {:ok, d} = Color.parse("oklch(62.8% 0.2577 none)")
      assert {:ok, e} = Color.parse("oklch(62.8% 0.2577 0)")
      assert_rgb(d, e)
    end

    test "rgb channels are clamped to 0..1" do
      assert Color.parse("rgb(300 0 0)") == {:ok, {1.0, 0.0, 0.0}}
      assert Color.parse("rgb(-20 0 0)") == {:ok, {0.0, 0.0, 0.0}}
      assert Color.parse("rgb(150% 0 0)") == {:ok, {1.0, 0.0, 0.0}}
    end

    test "out-of-range channels can be assessed" do
      assert {:ok, over} = Color.parse("rgb(300 -5 0)")
      assert {:ok, white} = Color.parse("#fff")
      assert is_float(Color.apca_lc(over, white))
      assert is_float(Color.wcag_ratio(over, white))
    end

    test "rgb( and rgba( are matched explicitly" do
      assert Color.parse("rgbfoo(1 2 3)") == :error
      assert Color.parse("rgb 1 2 3") == :error
    end

    test "alpha is ignored" do
      assert Color.parse("rgba(255, 0, 0, 0.5)") == {:ok, {1.0, 0.0, 0.0}}
      assert Color.parse("rgb(255 0 0 / 50%)") == {:ok, {1.0, 0.0, 0.0}}
      assert Color.parse("rgba(255 0 0 / .5)") == {:ok, {1.0, 0.0, 0.0}}
    end

    test "hsl" do
      assert {:ok, red} = Color.parse("hsl(0 100% 50%)")
      assert_rgb(red, {1.0, 0.0, 0.0})
      assert {:ok, green} = Color.parse("hsl(120 100% 25%)")
      assert_rgb(green, {0.0, 0.5, 0.0})
      assert {:ok, white} = Color.parse("hsl(0 0% 100%)")
      assert_rgb(white, {1.0, 1.0, 1.0})
      assert {:ok, blue} = Color.parse("hsla(240deg, 100%, 50%, 0.3)")
      assert_rgb(blue, {0.0, 0.0, 1.0})
      assert {:ok, wrapped} = Color.parse("hsl(-120 100% 50%)")
      assert_rgb(wrapped, {0.0, 0.0, 1.0})
      assert Color.parse("hsl(0 100)") == :error
    end

    test "oklch hue units" do
      {:ok, deg} = Color.parse("oklch(60% 0.15 180deg)")
      {:ok, turn} = Color.parse("oklch(60% 0.15 0.5turn)")
      {:ok, rad} = Color.parse("oklch(60% 0.15 #{:math.pi()}rad)")
      {:ok, grad} = Color.parse("oklch(60% 0.15 200grad)")
      {:ok, bare} = Color.parse("oklch(60% 0.15 180)")
      for c <- [turn, rad, grad, bare], do: assert_rgb(c, deg)
    end
  end

  defp assert_rgb({r, g, b}, {er, eg, eb}, delta \\ 0.001) do
    assert_in_delta r, er, delta
    assert_in_delta g, eg, delta
    assert_in_delta b, eb, delta
  end
end
