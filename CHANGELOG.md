# Changelog

## Unreleased

- Color: parses `hsl()`, `hsla()` and `rgba()`, clamps `rgb()` channels, accepts leading-dot and unit hues; bad numbers return `:error` instead of raising.
- Tokens: keeps an unterminated last declaration, names repeated selectors by their at-rule, anchors `name:` matching, resolves `var()` inside the block first.
- Contrast page: a stylesheet with no `--color-*` tokens renders a message instead of crashing.
- Inspector: landmark, focus-order, radio-group, clipping, disabled/inert and closed-`<details>` false positives fixed; `aria-pressed="mixed"` reads as "partially pressed". A static render that fails logs why at debug level before falling back to the iframe page.
- Declares `phoenix_html`, which the inspector uses directly.

## 0.1.0

First release: the Contrast page and the Inspector (Sounds like, Focus order, Stress) for
phoenix_storybook 1.4+.
