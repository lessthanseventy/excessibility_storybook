defmodule ExcessibilityStorybook.Color do
  @moduledoc """
  CSS color parsing and contrast math.

  Colors are `{r, g, b}` tuples of gamma-encoded sRGB in `0.0..1.0`. Out-of-gamut
  oklch values are clipped per channel, which is what browsers do too.
  """

  @type rgb :: {float(), float(), float()}

  @doc """
  Parses hex, `rgb()`/`rgba()`, `hsl()`/`hsla()` and `oklch()` into `{:ok, rgb}`, else `:error`.

  Alpha is ignored for contrast. Channels are clamped to the sRGB gamut.
  """
  @spec parse(String.t()) :: {:ok, rgb()} | :error
  def parse(css) do
    css |> String.trim() |> String.downcase() |> do_parse()
  end

  defp do_parse("#" <> hex) when byte_size(hex) in [3, 4] do
    hex |> String.graphemes() |> Enum.map_join(&(&1 <> &1)) |> then(&do_parse("#" <> &1))
  end

  defp do_parse("#" <> hex) when byte_size(hex) in [6, 8] do
    case Base.decode16(binary_part(hex, 0, 6), case: :lower) do
      {:ok, <<r, g, b>>} -> {:ok, {r / 255, g / 255, b / 255}}
      :error -> :error
    end
  end

  defp do_parse("rgb(" <> rest), do: parse_rgb(rest)
  defp do_parse("rgba(" <> rest), do: parse_rgb(rest)
  defp do_parse("hsl(" <> rest), do: parse_hsl(rest)
  defp do_parse("hsla(" <> rest), do: parse_hsl(rest)

  defp do_parse("oklch(" <> rest) do
    with [l, c, h] <- args(rest),
         {:ok, l} <- oklch_channel(l, &percent/1),
         {:ok, c} <- oklch_channel(c, &number/1),
         {:ok, h} <- oklch_channel(h, &hue/1) do
      {:ok, oklch_to_srgb(l, c, h)}
    else
      _ -> :error
    end
  end

  defp do_parse(_), do: :error

  defp parse_rgb(rest) do
    with [r, g, b] <- args(rest),
         {:ok, r} <- channel(r),
         {:ok, g} <- channel(g),
         {:ok, b} <- channel(b) do
      {:ok, {r, g, b}}
    else
      _ -> :error
    end
  end

  defp parse_hsl(rest) do
    with [h, s, l] <- args(rest),
         {:ok, h} <- hue(h),
         {:ok, s} <- percent(s),
         {:ok, l} <- percent(l) do
      {:ok, hsl_to_srgb(h, clamp(s), clamp(l))}
    else
      _ -> :error
    end
  end

  # "a b c)", "a, b, c, alpha)" or "a b c / alpha)" -> ["a", "b", "c"]; alpha is ignored
  defp args(rest) do
    if String.ends_with?(rest, ")") do
      rest
      |> String.trim_trailing(")")
      |> String.split("/")
      |> hd()
      |> String.split([" ", ","], trim: true)
      |> case do
        [_, _, _] = parts -> parts
        [a, b, c, _alpha] -> [a, b, c]
        _ -> :error
      end
    else
      :error
    end
  end

  defp oklch_channel("none", _parse), do: {:ok, 0.0}
  defp oklch_channel(s, parse), do: parse.(s)

  defp channel(s) do
    if String.ends_with?(s, "%") do
      with {:ok, n} <- percent(s), do: {:ok, clamp(n)}
    else
      with {:ok, n} <- number(s), do: {:ok, clamp(n / 255)}
    end
  end

  defp clamp(n), do: n |> max(0.0) |> min(1.0)

  defp percent(s) do
    if String.ends_with?(s, "%") do
      with {:ok, n} <- number(String.trim_trailing(s, "%")), do: {:ok, n / 100}
    else
      number(s)
    end
  end

  defp number(s) do
    case ~r/^([+-]?)\./ |> Regex.replace(s, "\\g{1}0.") |> Float.parse() do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  # "grad" must come before "rad"
  @hue_units [{"grad", 0.9}, {"deg", 1.0}, {"rad", 180 / :math.pi()}, {"turn", 360.0}]

  defp hue(s) do
    case Enum.find(@hue_units, fn {unit, _} -> String.ends_with?(s, unit) end) do
      {unit, deg_per_unit} ->
        with {:ok, n} <- number(String.trim_trailing(s, unit)), do: {:ok, n * deg_per_unit}

      nil ->
        number(s)
    end
  end

  defp hsl_to_srgb(h, s, l) do
    h = h - 360 * Float.floor(h / 360)
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(h / 60 - 2 * Float.floor(h / 120) - 1))
    m = l - c / 2

    {r, g, b} =
      cond do
        h < 60 -> {c, x, 0.0}
        h < 120 -> {x, c, 0.0}
        h < 180 -> {0.0, c, x}
        h < 240 -> {0.0, x, c}
        h < 300 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    {clamp(r + m), clamp(g + m), clamp(b + m)}
  end

  defp oklch_to_srgb(l, c, h) do
    rad = h * :math.pi() / 180
    a = c * :math.cos(rad)
    b = c * :math.sin(rad)

    l_ = :math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
    m_ = :math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
    s_ = :math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)

    {
      encode(4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_),
      encode(-1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_),
      encode(-0.0041960863 * l_ - 0.7034186147 * m_ + 1.7076147010 * s_)
    }
  end

  defp encode(linear) do
    v = linear |> max(0.0) |> min(1.0)
    if v <= 0.0031308, do: 12.92 * v, else: 1.055 * :math.pow(v, 1 / 2.4) - 0.055
  end

  @doc "WCAG 2.x contrast ratio, 1.0..21.0. Order doesn't matter."
  @spec wcag_ratio(rgb(), rgb()) :: float()
  def wcag_ratio(a, b) do
    [hi, lo] = Enum.sort([luminance(a), luminance(b)], :desc)
    (hi + 0.05) / (lo + 0.05)
  end

  defp luminance({r, g, b}), do: 0.2126 * decode(r) + 0.7152 * decode(g) + 0.0722 * decode(b)

  defp decode(c) when c <= 0.04045, do: c / 12.92
  defp decode(c), do: :math.pow((c + 0.055) / 1.055, 2.4)

  @doc """
  APCA lightness contrast (Lc), apca-w3 0.0.98G-4g. Order matters: text first.
  Positive is dark text on light, negative is light text on dark.
  """
  @spec apca_lc(rgb(), rgb()) :: float()
  def apca_lc(text, background) do
    y_txt = apca_y(text)
    y_bg = apca_y(background)

    cond do
      abs(y_bg - y_txt) < 0.0005 ->
        0.0

      y_bg > y_txt ->
        sapc = (:math.pow(y_bg, 0.56) - :math.pow(y_txt, 0.57)) * 1.14
        if sapc < 0.1, do: 0.0, else: (sapc - 0.027) * 100

      true ->
        sapc = (:math.pow(y_bg, 0.65) - :math.pow(y_txt, 0.62)) * 1.14
        if sapc > -0.1, do: 0.0, else: (sapc + 0.027) * 100
    end
  end

  defp apca_y({r, g, b}) do
    y =
      0.2126729 * :math.pow(r, 2.4) + 0.7151522 * :math.pow(g, 2.4) +
        0.0721750 * :math.pow(b, 2.4)

    if y < 0.022, do: y + :math.pow(0.022 - y, 1.414), else: y
  end
end
