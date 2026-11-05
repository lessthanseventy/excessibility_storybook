defmodule ExcessibilityStorybook.Color do
  @moduledoc """
  CSS color parsing and contrast math.

  Colors are `{r, g, b}` tuples of gamma-encoded sRGB in `0.0..1.0`. Out-of-gamut
  oklch values are clipped per channel, which is what browsers do too.
  """

  @type rgb :: {float(), float(), float()}

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

  defp do_parse("rgb" <> rest) do
    with [r, g, b] <- args(rest) do
      {:ok, {channel(r), channel(g), channel(b)}}
    end
  end

  defp do_parse("oklch" <> rest) do
    with [l, c, h] <- args(rest) do
      {:ok, oklch_to_srgb(percent(l), number(c), number(h))}
    end
  end

  defp do_parse(_), do: :error

  # "(a b c / alpha)" or "(a, b, c)" -> ["a", "b", "c"]; alpha is ignored
  defp args(rest) do
    rest
    |> String.trim_leading("a")
    |> String.trim()
    |> String.trim_leading("(")
    |> String.trim_trailing(")")
    |> String.split("/")
    |> hd()
    |> String.split([" ", ","], trim: true)
    |> case do
      [_, _, _] = parts -> parts
      _ -> :error
    end
  end

  defp channel(s), do: if(String.ends_with?(s, "%"), do: percent(s), else: number(s) / 255)

  defp percent(s) do
    if String.ends_with?(s, "%"), do: number(String.trim_trailing(s, "%")) / 100, else: number(s)
  end

  defp number(s) do
    {n, _} = Float.parse(s)
    n
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
