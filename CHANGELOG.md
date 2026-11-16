# Changelog

## 0.2.1

### Changed

- **Cache invalidation:** unified `_needsCacheReset`/`_needsReparse` into a single `_classifyRebuild` predicate; cache key now includes theme, builders, width and `NO_COLOR` state, preventing stale styles during streaming and theme switches.
- **NO_COLOR:** container/page background now resolves through `NoColor.resolve`, so backgrounds drop to the terminal default alongside text colors.
- Reduced `assets/demo.gif` below the 4 MB pub.dev screenshot limit and shortened the pubspec description to satisfy pub scoring.

### Added

- Regression tests for cache invalidation (theme change, `NO_COLOR` toggle) and Mermaid rasterization (A* bounds, protected cells, narrow widths, fallbacks).
- dartdoc for `AdaptiveMarkdownTheme`, `CodeToken` and `CodeHighlighter`.

## 0.2.0

### Added

- **List markers decoupled:** `showListMarkers` parameter on `MarkdownPlus` / `MarkdownPlusVisitor` controls bullets and ordered numbers independently of heading markers (`showMarkers`), so headings stay clean while lists keep their markers.
- **Custom palettes:** `MarkdownTheme.fromPalette(...)` builds a full theme from a handful of base colors, reusing `fromTuiTheme` derivation; defaults are catppuccin-like for light/dark.
- **Mermaid rendering:** orthogonal A* edge routing for flowcharts (Manhattan paths, protected cells prevent box corruption); diagram-specific `PieRenderer` (horizontal bar legend); dispatcher by diagram type; graceful fallback to source for unsupported types.
- **Image support:** standalone image paragraphs (`![alt](src)`) render as
  real terminal graphics via nocterm (Kitty / iTerm2 / Sixel /
  Unicode-blocks, default protocol: unicodeBlocks for reliability). File, `https://` and `data:` URIs are
  supported; `renderImages`, `imageMaxWidth` and `imageProtocol` parameters
  control rendering. Mixed paragraphs keep the `[Image: alt]` placeholder;
  a per-tag `img` builder still overrides.

### Changed

- **Seamless backgrounds:** code blocks and mermaid diagrams now blend into the page background by default (previously `fromTuiTheme` used the surface color, creating visible boxes). Built-in presets already did this; system themes now match.

## 0.1.3

### Added

- `example/nocterm_markdown_plus_example.dart` is now a runnable entry point (renamed from `demo.dart`).

### Changed

- `.pubignore` excludes `AGENTS.md`, `coverage/`, `test/`, `tool/` and
  `doc/` from the published archive.

## 0.1.2

### Added

- **NO_COLOR support:** honors `NO_COLOR` (https://no-color.org) at render
  time — when set (non-empty value, including `0`), all foreground and
  background colours are dropped to the terminal default while bold,
  italic, underline, strikethrough and glyphs are preserved. Implemented
  as a single choke point in `MarkdownStyle.toTextStyle()`, so it covers
  every theme slot, diff backgrounds and syntax tokens. `NoColor` is
  exported from the package entry point with `enabled`, `enabledIn` and
  `setOverride` (for tests and hosts reading their own configuration).

- **Dimmed rendering:** `MarkdownTheme.dimmed({factor})` (and
  `MarkdownStyle.dimmed`) blend every colour toward the page background, so
  LLM "thinking" output can be rendered ~50% dimmer without competing
  with the answer. Composes with `quantizedToAnsi256`.

### Changed

- **Diff rendering** now uses a coloured background (VS Code style) with
  code-coloured, syntax-highlighted text instead of flat coloured lines;
  language is detected from the `---`/`+++`/`diff --git` headers. Hunk
  headers and git metadata keep their own colours.
- Consolidated the duplicated colour-blend helper into a single
  `blendColors` in `markdown_theme.dart` (presets and `fromTuiTheme`
  now share it).

## 0.1.1

### Added

- **Front matter:** a leading YAML `---` … `---` block is metadata, not
  prose — it is skipped by default; a `'front_matter'` per-tag builder can
  render it. A `---` first line without a closer stays an ordinary
  horizontal rule.

### Fixed

- Malformed alert divs (`markdown-alert` without a known type) crashed the
  renderer; they now render as ordinary content.
- `footnoteRefStyle.prefix`/`suffix` glyphs were ignored — they now wrap the
  `[n]` reference.
- Exact grays (e.g. `#808080`) snapped to the color cube during `ansi256`
  quantization instead of staying on the gray ramp.
- Dead code removed (`AsciiCanvas.fill`/`overwrite`).

## 0.1.0

### Added

- **Themed markdown slots:** task checkbox styles, image text style, definition
  list styles, `prefix`/`suffix` glyphs on `MarkdownStyle` (list markers, quote
  bars, inline-code padding now live in the style), and a colorless ASCII
  fallback theme (`MarkdownThemes.ascii`) with literal markers (`**bold**`).
- **LLM content:** GitHub alerts (`> [!NOTE]` … `[!CAUTION]`) with per-type
  icons and styles, footnotes (refs + definition block), emoji shortcodes,
  definition lists (`term` / `: description`), autolink polish (bare URLs no
  longer repeat themselves in brackets).
- **Streaming:** a shared block memo-cache reuses settled blocks, so growing
  chat replies re-render only their tail (`MarkdownPlus` does this
  transparently).
- **Per-tag builders:** `MarkdownPlusBuilder` map on the widget to replace the
  renderer of any tag (`code`, `table`, `a`, …) without forking the engine.
- **Render options:** explicit `maxWidth` and `ansi256` quantization to the
  xterm-256 palette.
- **Diff rendering:** fenced `diff`/`patch` blocks render as colorized diffs
  (additions, removals, hunk headers, git metadata) driven by four new theme
  slots: `diffAddedStyle`, `diffRemovedStyle`, `diffHunkStyle`,
  `diffMetaStyle` (JSON-serializable, set by every preset and
  `fromTuiTheme`).
- **Upgraded tables:** a rule between every row, inline markdown rendered
  inside cells (bold/italic/code/links with cell wrapping by display
  width), and column alignment from the GFM delimiter row (`:---`,
  `:---:`, `---:`).
- **Core model:** `MarkdownTheme` with 40+ element style slots (+ `copyWith`,
  JSON `fromJson`/`toJson`), `MarkdownStyle`, `SyntaxTheme`,
  `AdaptiveMarkdownTheme`, and `MarkdownTheme.fromTuiTheme`.
- `MarkdownTheme.background` — `MarkdownPlus` paints its rendered area with
  the theme background (presets reuse the code-block background color, so
  blocks and page share one surface); JSON-serializable and set by
  `MarkdownTheme.fromTuiTheme`.
- `MarkdownPlus` widget — themed markdown rendering for nocterm, superset of
  the core `MarkdownText`: ordered-list numbering, task-list checkboxes,
  conceal mode, styled tables, themed code blocks.
- `MarkdownThemes` presets: 12 dark (Catppuccin Mocha, Nord, Dracula,
  Tokyo Night, One Dark, Gruvbox Dark, Monokai, GitHub Dark, Ayu Dark,
  Solarized Dark, Matrix, nocterm) + 6 light (Catppuccin Latte, Solarized
  Light, GitHub Light, One Light, Ayu Light, nocterm light), and
  `AdaptiveMarkdownTheme` pairs for the five families shipping both.
- `CodeHighlighter` interface with `PlainHighlighter` fallback, and
  `SyntaxCoreHighlighter` — real TextMate syntax highlighting (VS Code/Shiki
  parity, ~20 languages) mapped onto theme syntax slots.
- Example gallery app (`example/demo.dart`) with theme cycling, keyboard
  scrolling, chrome painted from the active markdown theme, and
  terminal-mode restoration on quit (no leftover `-echo` shell state).
- Unit and widget test suites; `tool/contrast_audit.dart` keeps every preset
  above WCAG AA (4.5:1).

### Fixed

- Diagram scaling: the rasterizer stretched every diagram to fill the
  available width, inflating actor boxes to 26+ columns and doubling
  vertical spacing. Diagrams now map at the natural 8x16 px cell scale and
  only shrink proportionally when they exceed the max width.
- Sequence diagrams: message labels are now rendered (they live inside the
  edge group, not in a separate edge-label group), arrowheads are no longer
  overwritten by lifelines, actor boxes render square instead of rounded, and
  shape/text metrics use the real cell scale instead of hardcoded divisors.
  Cyrillic and other non-ASCII labels render at their true widths.
- Sequence diagram text: message labels were positioned from their bounds
  width divided by the cell scale (SVG measurer units), drifting far left of
  the arrow midpoint, and autonumbers glued to their labels ("2запрашивает").
  Labels now anchor on the bounds center/right edge shifted by real character
  length, and texts sharing a row are laid out with at least one blank cell
  between them. Node boxes hug their label centered over the IR rect, so the
  last actor box no longer overflows the canvas edge.
- Sequence diagram `actor` nodes: the stick figure (torso path + head circle)
  has no box rect, so the actor's name box was rasterized from the torso
  bounds — one row below the participants' boxes, colliding with the
  lifelines. Node groups now rasterize from the union bounds of all their
  shapes, and shrunken diagrams anchor lifelines to the drawn box bottom so
  no box floats above its lifeline.
- Light themes rendered body text in the terminal default color (white),
  making paragraphs invisible on light backgrounds. Paragraphs now fall back
  to the theme's `textStyle` when no explicit `paragraphStyle` is set.
- Light themes rendered list item text in the terminal default color (white):
  bare text nodes inside `<li>` carry no style and markers/numbering painted
  over them. The list-item wrapper now supplies the theme's `textStyle`, so
  bullets, enumeration, task checkboxes and item text match the theme;
  inline markup inside items keeps its own colors.
- Code blocks render no phantom trailing line and leave a blank line after
  the block; line numbers only cover real code lines.
- Tables ignore delimiter-looking rows that leak into the body, so column
  widths can never inflate.
- `MarkdownTheme.copyWith` silently dropped `background`: copying a preset to
  restyle a few slots also removed the page backdrop. The parameter is now
  carried over (and overridable).
- `MarkdownTheme` equality ignored `background`, so two themes differing only
  in backdrop compared equal; it now participates in `==`/`hashCode`.
- `MarkdownPlus` did not re-render when only `ansi256` or `builders` changed
  (stale colors/styles painted), and a `maxWidth` change re-parsed without
  clearing the block memo-cache, keeping rules and tables at their old width
  after a resize.
- The block memo-cache keyed on raw text only: a heading sharing text with an
  earlier paragraph rendered as that paragraph, `hr` collided with any other
  empty block, and code blocks with identical code but different languages
  shared one highlighting. Keys now include the tag and code language.

### Changed

- Syntax highlighting is now the default: `MarkdownPlus.highlighter` defaults to
  `SyntaxCoreHighlighter` instead of plain rendering. Pass
  `const PlainHighlighter()` for unhighlighted code blocks.
