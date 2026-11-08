# Changelog

## Unreleased

- Color: parses `hsl()`, `hsla()` and `rgba()`, clamps `rgb()` channels, accepts leading-dot and unit hues; bad numbers return `:error` instead of raising.
- Tokens: keeps an unterminated last declaration, names repeated selectors by their at-rule, anchors `name:` matching, resolves `var()` inside the block first.
- Contrast page: a stylesheet with no `--color-*` tokens renders a message instead of crashing.
- Inspector: landmark, focus-order, radio-group, clipping, disabled/inert and closed-`<details>` false positives fixed; `aria-pressed="mixed"` reads as "partially pressed". A static render that fails logs why at debug level before falling back to the iframe page.
- Inspector: radio groups are scoped to their form and skip radios that can't take focus; content behind a modal dialog and extra `<summary>` elements are not tab stops; a role-less tab stop is reported; an ellipsis counts as clipping unless `title` or `aria-label` carries the full text; a `line-clamp` does not; the data-table reflow exemption holds only when nothing else overflows; a named closed `<details>` is announced as a group.
- Tokens: a `var()` that several selectors set differently (`:root` and `.dark`) gives one theme per selector; blocks sharing a selector are one theme.
- Color: bare `hsl()` percentages and `none` parse; four space-separated parts without a slash are an error.
- Contrast page shows the stylesheet's file name, not its server path.
- Declares `phoenix_html`, which the inspector uses directly.

## 0.1.0

First release: the Contrast page and the Inspector (Sounds like, Focus order, Stress) for
phoenix_storybook 1.4+.
