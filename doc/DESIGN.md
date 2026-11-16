# nocterm_markdown_plus — Design & Decision Log

> Themed markdown rendering for [nocterm](https://pub.dev/packages/nocterm).

## 1. Positioning (D1)

Universal **themed** markdown for nocterm: documents, help screens, README rendering in TUI apps.
Non-goals v1: streaming/incremental rendering, own markdown parser, Flutter compatibility. Terminal images are supported since 0.2.0 (block-level `Image` components).

Market validation (2026-11-12): nocterm 167k downloads/mo, 413★ GitHub, 21 nocterm-* packages,
**zero nocterm markdown packages on pub.dev**, demand signals in nocterm issues #45/#105, cross-ecosystem
proof (popular terminal renderers, ~28k stars each).

## 2. Decisions

| # | Decision | Alternatives | Rationale |
|---|---|---|---|
| D1 | Universal themed markdown (static) | Chat/streaming rendering | Simpler entry; streaming is a non-goal for v1 |
| D2 | Full syntax highlighting behind a `CodeHighlighter` adapter | Colors-only / own regex tokenizer | Pure-Dart TextMate highlighter exists; adapter isolates young deps |
| D3 | Own superset visitor on the public nocterm API | Vendor core visitor / wrap core `MarkdownText` | Full control of slots + fidelity; no core-code fork to diff |
| D4 | Themes: presets + custom (code/JSON) + brightness-adaptive | Presets only | Max theme coverage; nocterm core provides brightness detection |
| D5 | MIT license | Apache-2.0 | Ecosystem is uniformly MIT; MIT deps; minimal friction |
| D6 | Front matter: skip by default, `'front_matter'` builder tag | Styled metadata block (new theme slots) | It is app metadata, not prose; zero API growth, builders give opt-in rendering |
| D7 | NO_COLOR as a single choke point in `MarkdownStyle.toTextStyle()` | Global registry mirroring file_color's `TerminalColors` | Render-time check covers every slot, diff backgrounds and syntax tokens uniformly; builders' own spans stay untouched |
| D8 | `dimmed()` blends colours toward the page background | Brightness × 0.5 | Preserves hue on light/dark themes; flags/glyphs/page background unchanged; composes with `quantizedToAnsi256` |
| D9 | Images render as block-level components, not inline spans (default protocol: unicodeBlocks for reliability) | WidgetSpan (unavailable in nocterm) / ASCII art | Nocterm has no WidgetSpan, so a standalone image paragraph becomes its own component interleaved in a Column; mixed paragraphs keep the `[Image: alt]` placeholder; per-tag `img` builder still overrides |
| D10 | Hybrid mermaid rendering: orthogonal A* router for flowcharts + diagram-specific renderers for non-rectangular types | Pure generic rasterizer / full rewrite | Generic rasterizer can't render pie/gantt/sankey/gitgraph/mindmap/journey meaningfully; mermaid_core stays (solid parser+layout); protected cells prevent box corruption; A* with turn penalty gives clean Manhattan paths; diagram-specific renderers read mermaid_core's parsed model (pie → horizontal bar legend) |
| D11 | `MarkdownTheme.fromPalette` — build a theme from base colors, reusing `fromTuiTheme` derivation | Separate derivation logic | DRY: palette is normalized into a `TuiThemeData` and delegated; defaults are catppuccin-like for both light/dark |
| D12 | Code/mermaid backgrounds merge into page background by default | Surface-colored boxes for code blocks | Terminal UIs look cleaner without contrasting rectangles; built-in presets already did this, `fromTuiTheme` now matches; surface reserved for elevated widgets |

## 3. Key findings (Phase 0 spike)

- nocterm core 0.9.0 exposes: `TuiThemeData` (6 presets: dark/light/nord/dracula/catppuccinMocha/gruvboxDark),
  `TuiTheme.of(context)`, `AdaptiveColor`, `detectTerminalBrightness(terminal)` (OSC 11 → COLORFGBG →
  macOS → default dark), `Terminal.getBackgroundColor`. No OSC-4 palette-query public API → system theme
  derives from **brightness** + theme family (not raw 16-color palette); risk retired.
- `syntax_core` 0.0.3 (BSD-3): TextMate grammars (VS Code/Shiki parity), pure Dart, tree-shakeable
  per-grammar/per-theme imports, neutral output (ARGB + scopes), `toAnsi()`. 18 languages; themes include
  catppuccin (latte/mocha), nord, dracula, tokyo-night, monokai, github dark/light, one-dark-pro,
  vitesse, solarized-light. **Unknown language throws** → adapter must try/catch + plain fallback.
- opal 0.3.0: weaker fit (experimental, no bundled themes). Rejected as default adapter backend.

## 4. Architecture

### 4.1 Theme model

`MarkdownTheme` — immutable, const-constructible, `copyWith`, `==`/`hashCode`, `toJson`/`fromJson`.

Markdown slots:

| Slot | Role |
|---|---|
| `text` | Base paragraph text |
| `h1`…`h6` | Heading levels (terminal: color/weight differences) |
| `paragraph` | Optional paragraph override |
| `strong` / `emph` / `del` | Bold / italic / strikethrough |
| `code` / `codeBg` | Inline code fg/bg |
| `codeBlock` / `codeBlockBg` | Code block fg/bg |
| `blockQuote` / `blockQuoteBar` | Quote text / left bar |
| `link` / `linkText` | URL / link text |
| `listBullet` / `listEnumeration` | Bullet glyph / ordered markers |
| `horizontalRule` | `---` |
| `tableHeader` / `tableBorder` / `tableCell` | Table chrome |
| `image` | Image placeholder text |

Code-block theming: tokens are mapped onto the markdown theme's own `SyntaxTheme`
(10 slots: keyword/string/number/comment/function/variable/type/operator/
punctuation/plain) so code blocks stay visually consistent with the active
markdown theme; `codeBlockBg` provides the block background. The highlighter
is pluggable via the `CodeHighlighter` interface.

Brightness: every preset is dark or light (`MarkdownTheme.brightness`);
`AdaptiveMarkdownTheme` pairs resolve via `detectTerminalBrightness` or
`TuiTheme.of(context).brightness`.

Integrations:
- `MarkdownTheme.fromTuiTheme(TuiThemeData)` — derive slots from an app's nocterm theme (consistency).
- Presets: `MarkdownThemes.catppuccinMocha`, `.nord`, `.dracula`, `.tokyoNight`, `.oneDark`,
  `.gruvboxDark`, `.monokai`, `.githubDark`, `.ayuDark`, `.solarizedDark` (+ light pairs in 0.2.0).

### 4.2 Renderer

`MarkdownPlus(data, {theme, highlighter, showMarkers, lineNumbers, maxLines, textAlign, softWrap})` →
`StatefulComponent` → `LayoutBuilder` → `RichText(TextSpan)` (public nocterm API; cache keyed by
data/theme/width, mirroring core `MarkdownText`).

`MarkdownPlusVisitor` (superset of core visitor, fixes core gaps):
- ordered lists with numbering (core: "not yet implemented"), `start` attribute honored
- task lists (`[x]`/`[ ]` → `✓`/`☐` styled marker) — nocterm issue #105
- nested list indentation, list bullet/enumeration slots
- `showMarkers: false` conceals `#`/`│`/list bullet glyphs and ordered
  numbers; task checkboxes stay — they are rendered task
  state, not source syntax
- code blocks: per-line bg spans, optional line numbers, highlighter spans or plain
- tables: core's unicode-width grid algorithm, cells as **styled spans** (core emits one flat span)
- links `text [url]`, hr to maxWidth, images `[Image: alt]`

`CodeHighlighter` interface + `SyntaxCoreHighlighter` (default, wraps `syntax_core`, try/catch
unknown-language fallback) + `PlainHighlighter` (opt-in, no dependencies).

Unicode width util vendored from nocterm core (MIT) with attribution in LICENSE.

### 4.3 Package layout

```
lib/nocterm_markdown_plus.dart
lib/src/markdown_plus.dart
lib/src/theme/{markdown_theme,presets}.dart
lib/src/render/{markdown_visitor,code_block_renderer,table_renderer}.dart
lib/src/highlight/{code_highlighter,syntax_core_highlighter}.dart
lib/src/util/unicode_width.dart                  (vendored, MIT)
example/nocterm_markdown_plus_example.dart         (gallery + streaming demo)
test/                                             (unit + widget via nocterm test harness)
```

Versioning: nocterm `>=0.9.0 <0.10.0`, CI re-checked on each core release.
Everything (theme model, fidelity, light presets, adaptive pairs, syntax
highlighting adapter) ships in a single 0.1.0 release.

### Update log

- **Seamless backgrounds (0.2.0):** code blocks and mermaid diagrams now blend into the page background in `fromTuiTheme` (surface no longer used for code backgrounds), matching built-in presets.
- **Custom palettes (0.2.0):** `MarkdownTheme.fromPalette(...)` builds a full theme from a handful of base colors, reusing `fromTuiTheme` derivation; defaults are catppuccin-like for light/dark.
- **Mermaid rendering (0.2.0):** orthogonal A* edge routing for flowcharts (turn-penalized Manhattan paths, node cells protected so edges never overwrite box borders/labels); diagram-specific renderer abstraction with `PieRenderer` PoC (horizontal bar legend, fixed 20-cell width); dispatcher in `MermaidRenderer` by `DiagramType`; fallback to source code preserved. Protected-cell fix + A* + pie validated on 15 diagram types.
- **Images (0.2.0):** standalone image paragraphs render as nocterm `Image` components (Kitty/iTerm2/Sixel/Unicode-blocks, auto-detected); file/https/data-URI sources; `renderImages`/`imageMaxWidth`/`imageProtocol` params; mixed paragraphs keep the `[Image: alt]` placeholder; per-tag `img` builder still overrides.
- **0.1.2 — NO_COLOR + dimmed + diff rewrite:** `NoColor` honored at render time through `MarkdownStyle.toTextStyle()`; `MarkdownTheme.dimmed()` for LLM thinking output; diff renderer now uses coloured backgrounds + syntax highlighting with language detection; duplicated `blend` helper consolidated into `blendColors`; coverage gate excludes vendored unicode util (87%).
- **Front matter split (0.2.0):** `parseDocument` peels a leading
  `---`…`---` YAML block into a `front_matter` element before the parser
  runs; the visitor skips it and a per-tag builder can render it. A `---`
  first line without a closer stays an ordinary horizontal rule.
- **0.1.0 published on pub.dev** (repo: AmidVoshakul/nocterm_markdown_plus).
- **Mermaid pipeline:** `mermaid` fences route through a self-contained
  rasterizer (`lib/src/diagram/`): a grid canvas with box-drawing
  primitives, scene walk over the diagram IR (nodes/edges/labels), and a
  fallback to source code for unknown diagram types. Works for pure-Dart
  hosts without any TUI-framework dependency.
- **xterm-256 quantization:** `MarkdownTheme.quantizedToAnsi256()` snaps
  colors to the 256-color cube/gray ramp.

- **Emoji switching to `ExtensionSet.gitHubWeb`:** the upstream package's
  GitHub-Web set already provides `AlertBlockSyntax`, `FootnoteDefSyntax`,
  `EmojiSyntax`, and `ColorSwatchSyntax`, so alerts, footnotes, and emoji
  render without custom syntaxes. Definition lists are an AST post-pass
  (`lib/src/parse/markdown_document.dart`) because the parser treats
  `term\n: desc` as one lazy paragraph; nested elements are rebuilt rather
  than mutated because list elements carry `List<Element>` children.
- **Style slots:** `prefix`/`suffix` glyphs move into `MarkdownStyle`
  (item/quote/code markers), task checkbox styles and definition/alert/footnote
  slots added; `MarkdownThemes.ascii` is the colorless notty-style fallback.
- **Streaming memo-cache:** the widget owns a `Map<String, List<InlineSpan>>`
  keyed by block text; settled blocks are reused across renders, the cache is
  reset when theme/markers/highlighter/builders change.
- **Per-tag builders:** `MarkdownPlusBuilder` consulted before the built-in
  tag renderer; `null` keeps the default.
- **ansi256:** `MarkdownTheme.quantizedToAnsi256()` snaps colors to the
  xterm-256 cube/gray ramp (nearest by squared distance).
- **Cut from scope:** OSC 8 hyperlinks — the host framework paints cells with
  its own truecolor escape writer and exposes no hyperlink API, so escape
  sequences would be drawn as literal text. Revisit if the host adds support.

- **Highlighting is the default:** `MarkdownPlus.highlighter` defaults to
  `SyntaxCoreHighlighter`; plain rendering is opt-in via `PlainHighlighter`.
- **Diff rendering added:** `lib/src/render/diff_renderer.dart` classifies
  unified-diff lines (metadata / hunk / added / removed / context) onto the
  four `diff*` theme slots; `MarkdownPlusVisitor` routes `diff`/`patch`
  fenced blocks to it. Verified in tmux: `+` lines render in the theme's
  green, `-` in its red under catppuccin.
- **Table renderer rebuilt:** row separators between every row; cells render
  inline markdown via the visitor and wrap by display width with per-run
  styles; alignment parsed from the delimiter row; border lines carry their
  newline inside the styled span (same emission shape as horizontal rules,
  which keeps them robust across terminals).

- **Theme background added:** `MarkdownTheme.background` (Color) is painted
  by `MarkdownPlus` over its area; presets set it to the code-block
  background so blocks blend into the page; `fromTuiTheme` uses the host
  app background.
- **Code block fixes:** trailing phantom line removed (content is trimmed
  before rendering), explicit blank line after each block.
- **Table hardening:** delimiter-looking rows in the body are skipped so
  column widths cannot inflate.

- **Light presets added:** Catppuccin Latte, Solarized Light, GitHub Light,
  One Light, Ayu Light (+ nocterm light); `MarkdownThemes.darkGallery` /
  `.lightGallery` / `.gallery` / `.adaptive` (5 dark/light pairs).
- **SyntaxCoreHighlighter added (adapter over `syntax_core` 0.0.3):**
  TextMate grammars, `bundledLanguages`, stateful line tokenization,
  scope-stack to `CodeTokenType` mapping (comment/string/number/keyword/
  type/function/variable/operator/punctuation/plain), plain fallback on
  unknown language or failure. Verified: a dart block under Catppuccin Mocha
  produces 7 distinct theme-consistent colors.

## 5. Risks

| Risk | Mitigation |
|---|---|
| syntax_core is 4 days old (0.0.3) | Pin; adapter behind interface; PlainHighlighter always works |
| nocterm 0.x churn | `<0.10.0` constraint; CI matrix; fast patch releases |
| Core absorbs features | Differentiation = themes + fidelity + syntax; contribute upstream |
| Small Dart-TUI audience | Modest success criteria |

## 6. Success criteria (review at 3 months)

0.1.0: ≥300 downloads, ≥5 likes. 0.3.0: ≥800 total downloads, ≥10 likes, ≥1 external adopter.
