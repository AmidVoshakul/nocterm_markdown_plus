import 'dart:io' show stdin;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';

const _sample = '''
# nocterm_markdown_plus

The themed markdown renderer for *nocterm*.

## Features

1. Rich color themes with light/dark support
2. Styled tables with *proper* cell colors
3. Task lists rendered as checkboxes

- [x] Syntax-aware inline styling
- [x] Conceal mode for rendered output
- [ ] Streaming re-renders only the new tail

## Code

Inline `code` and fenced blocks with backgrounds:

```dart
void main() {
  final theme = MarkdownThemes.catppuccinMocha;
  runApp(MarkdownPlus('# Hello', theme: theme));
}
```

## Table

| Feature      | Status | Notes                     |
|--------------|--------|---------------------------|
| Themes       | done   | 12 dark presets shipped   |
| Task lists   | done   | GitHub flavored           |
| Streaming    | done   | only the tail re-renders  |

> Terminal markdown deserves better than bold ASCII.

## LLM extras

> [!WARNING]
> Beware: the demos are addictive.

> [!TIP]
> Everything a model can emit renders here: :rocket: emoji, alerts,
> definition lists:

markdown
: A lightweight markup language.

## Diff

```diff
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,3 +1,3 @@
 void main() {
-  runApp(const OldApp());
+  runApp(const NewApp());
 }
```

## Diagram

Mermaid blocks render as terminal art — boxes, edges and labels:

```mermaid
sequenceDiagram
    autonumber
    actor User as Пользователь
    participant Pkg as Dart Package
    participant Parser as Markdown Parser
    participant MEngine as Mermaid Engine
    
    User->>Pkg: render(markdownContent)
    Pkg->>Parser: Разбор на блоки (AST)
    Parser-->>Pkg: Возврат токенов
    Pkg->>MEngine: Рендеринг диаграммы
    MEngine-->>Pkg: ASCII/Unicode Grid
    Pkg-->>User: Вывод стилизованного UI в консоль
```

---

[nocterm](https://nocterm.dev) · [nocterm_markdown_plus](https://github.com/AmidVoshakul/nocterm_markdown_plus)
''';

void main() {
  runApp(const MarkdownGallery());
}

class MarkdownGallery extends StatefulComponent {
  const MarkdownGallery({super.key});

  @override
  State<MarkdownGallery> createState() => _MarkdownGalleryState();
}

class _MarkdownGalleryState extends State<MarkdownGallery> {
  int _index = 0;
  bool _showMarkers = true;
  bool _lineNumbers = false;
  bool _highlighting = true;
  bool _dimmed = false;

  MarkdownTheme get _theme {
    final t = MarkdownThemes.gallery[_index];
    return _dimmed ? t.dimmed() : t;
  }

  CodeHighlighter? get _highlighter =>
      _highlighting ? const SyntaxCoreHighlighter() : null;

  bool _onKey(KeyboardEvent event) {
    switch (event.logicalKey) {
      case LogicalKey.arrowRight:
        setState(() => _index = (_index + 1) % MarkdownThemes.gallery.length);
      case LogicalKey.arrowLeft:
        setState(() => _index = (_index - 1) % MarkdownThemes.gallery.length);
      case LogicalKey.keyM:
        setState(() => _showMarkers = !_showMarkers);
      case LogicalKey.keyN:
        setState(() => _lineNumbers = !_lineNumbers);
      case LogicalKey.keyH:
        setState(() => _highlighting = !_highlighting);
      case LogicalKey.keyD:
        setState(() => _dimmed = !_dimmed);
      case LogicalKey.keyQ:
        _quit();
      case LogicalKey.keyC when event.isControlPressed:
        // The framework's own Ctrl+C path cannot restore terminal modes,
        // so quit through _quit() there too.
        _quit();
      default:
        return false;
    }
    return true;
  }

  /// Restores the terminal line discipline, then quits.
  ///
  /// The framework cancels its stdin subscription before re-enabling the
  /// terminal modes, so the shell would otherwise be left without echo. The
  /// modes must be restored while stdin is still listening.
  void _quit() {
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {
      // Piped stdin, tests, or already-closed stdin; best effort.
    }
    shutdownApp();
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _onKey,
      child: Container(
        color: _theme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: _theme.codeBackgroundStyle?.background,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                children: [
                  Text(
                    ' nocterm_markdown_plus ',
                    style: TextStyle(
                      color: _theme.h1Style?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' ${_theme.name} (${_index + 1}/${MarkdownThemes.gallery.length}) ',
                    style: TextStyle(color: _theme.textStyle?.color),
                  ),
                  Expanded(child: SizedBox()),
                  Text(
                    ' ←/→ theme · m markers · n line numbers · h highlight · d dim · q quit ',
                    style: TextStyle(color: _theme.horizontalRuleStyle?.color),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardScrollable: true,
                padding: const EdgeInsets.all(1),
                child: MarkdownPlus(
                  _sample,
                  theme: _theme,
                  highlighter: _highlighter,
                  showMarkers: _showMarkers,
                  lineNumbers: _lineNumbers,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
