import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';

void main() {
  runApp(const ChatDemo());
}

class ChatDemo extends StatefulComponent {
  const ChatDemo({super.key});

  @override
  State<ChatDemo> createState() => _ChatDemoState();
}

class _ChatDemoState extends State<ChatDemo> {
  static const _agents = ['Plan', 'Build', 'Ask'];
  static const _agentColors = [Colors.yellow, Colors.blue, Colors.green];

  int _themeIndex = 0;
  MarkdownTheme? _systemTheme;
  List<MarkdownTheme> get _themes {
    _systemTheme ??= MarkdownTheme.fromTuiTheme(
      TuiTheme.of(context),
      name: 'system',
    );
    return <MarkdownTheme>[_systemTheme!, ...MarkdownThemes.gallery];
  }

  int _agentIndex = 0;
  int _phase = 0; // 0 thinking, 1 answering, 2 done
  String _thinkingText = '';
  String _answerText = '';
  Timer? _timer;
  Timer? _shimmerTimer;
  int _cursor = 0;
  int _shimmerTick = 0;
  String _fullThinking = '';
  String _fullAnswer = '';
  final Random _rand = Random();
  final _scrollController = AutoScrollController();
  final _inputController = TextEditingController(text: 'Ask anything…');

  MarkdownTheme get _theme => _themes[_themeIndex];

  Color get _agentColor => _agentColors[_agentIndex];

  static const _thinking = r'''
The user wants a *live* preview of `nocterm_markdown_plus` rendering a streamed LLM answer. That means the renderer must handle incremental updates gracefully: each new chunk re-parses only the growing tail while reusing already-settled blocks from the memo cache.

Key considerations for the demo:

- Use a dimmed theme for the thinking block so it reads as secondary.
- Stream the answer with variable speed to mimic real token delivery.
- Show headings, code, tables, lists, alerts, diffs and links.
- Keep `showMarkers: false` so headings stay clean without `#`.

`MarkdownPlus` handles all of this out of the box, including the block cache and per-tag builders. The only thing the host needs to do is feed growing text and call `setState`.

> Terminal markdown deserves better than bold ASCII.
''';

  static const _response = r'''
Themed Markdown for **nocterm** — 19 themes, styled tables, task lists,
syntax-highlighted code, diffs, alerts, and terminal images.

## Features

- [x] Rich color themes (light & dark)
- [x] Styled tables with alignment
- [x] Task lists & nested lists
- [x] Syntax highlighting (TextMate)
- [x] `NO_COLOR` and `dimmed()` output

## Lists

Ordered list with longer descriptions:

1. **First item** — initializes the `parser` and prepares the *AST* for rendering
2. **Second item** — applies the theme slots to every inline span
3. **Third item** — flushes the trailing newline and returns the span tree

Unordered list of supported features:

- Rich color themes with **light** and *dark* variants
- Styled tables with `proper` cell colors and alignment
- Task lists rendered as interactive checkboxes
- Syntax-highlighted `code` blocks with backgrounds

Nested list with detailed children:

- **Outer item one**
  - Inner child describing the *first* sub-step
  - Inner child with `inline code` example
- **Outer item two**
  - A deeper nested grandchild entry
- Last outer item with a longer description that wraps across multiple lines

## Code

```dart
void main() {
  final theme = MarkdownThemes.catppuccinMocha;
  runApp(MarkdownPlus('# Hello', theme: theme));
}
```

## Table

| Capability | Status | Notes                              |
|------------|--------|------------------------------------|
| **Themes** | done   | 19 presets                         |
| **Tables** | done   | GFM, alignment                     |
| **Diff**   | done   | background + tokens                |
| **Images** | done   | **Kitty**/**iTerm2**/**Sixel**     |

> Terminal markdown deserves better than bold ASCII.

## Alerts & extras

> [!TIP]
> Emoji :rocket:, alerts, and definition lists all render:
>
> markdown
> : A lightweight markup language.

## Images

Standalone image paragraphs render as real terminal graphics:

![demo](assets/demo.png)

A paragraph that mixes text and an image keeps its `[Image: alt]` placeholder:
hello ![alt](assets/demo.png) world.

## Mermaid
```mermaid
flowchart LR
    A[Markdown] --> B[Parser]
    B --> C[Visitor]
    C --> D[Theme]
    D --> E[Terminal]
```
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

---

[nocterm](https://nocterm.dev) · [nocterm_markdown_plus](https://github.com/AmidVoshakul/nocterm_markdown_plus)
''';

  @override
  void initState() {
    super.initState();
    _fullThinking = _thinking;
    _inputController.selection = const TextSelection.collapsed(offset: 0);
    _fullAnswer = _response;
    _startStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmerTimer?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _startStream() {
    _timer?.cancel();
    _shimmerTimer?.cancel();
    _thinkingText = '';
    _answerText = '';
    _cursor = 0;
    _phase = 0;

    _shimmerTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted || _phase >= 1) {
        t.cancel();
        return;
      }
      setState(() => _shimmerTick++);
    });

    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    if (!mounted) return;

    int delayMs = 15;

    if (_phase == 0) {
      if (_cursor >= _fullThinking.length) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            _phase = 1;
            _cursor = 0;
          });
          _shimmerTimer?.cancel();
          _scheduleNextTick();
        });
        return;
      }

      final currentChar = _fullThinking[_cursor];
      if (currentChar == '.' || currentChar == ',') {
        delayMs = 10 + _rand.nextInt(15);
      } else {
        delayMs = 10 + _rand.nextInt(15);
      }

      final next = (_cursor + 1).clamp(0, _fullThinking.length);
      setState(() {
        _thinkingText = _fullThinking.substring(0, next);
        _cursor = next;
      });
    } else if (_phase == 1) {
      if (_cursor >= _fullAnswer.length) {
        setState(() => _phase = 2);
        return;
      }

      int chunkSize = 1 + _rand.nextInt(2);
      final currentChar = _fullAnswer[_cursor];
      if (currentChar == '\n' || currentChar == '#' || currentChar == '`') {
        delayMs = 20 + _rand.nextInt(20);
        chunkSize = 1;
      } else {
        delayMs = 10 + _rand.nextInt(15);
      }

      final next = (_cursor + chunkSize).clamp(0, _fullAnswer.length);
      setState(() {
        _answerText = _fullAnswer.substring(0, next);
        _cursor = next;
      });
    }

    if (_phase < 2) {
      _timer = Timer(Duration(milliseconds: delayMs), _scheduleNextTick);
    }
  }

  void _quit() {
    try {
      stdin.echoMode = true;
      stdin.lineMode = true;
    } catch (_) {}
    shutdownApp();
  }

  bool _onKey(KeyboardEvent event) {
    switch (event.logicalKey) {
      case LogicalKey.arrowRight:
        setState(
          () => _themeIndex = (_themeIndex + 1) % MarkdownThemes.gallery.length,
        );
      case LogicalKey.arrowLeft:
        setState(
          () => _themeIndex =
              (_themeIndex - 1 + MarkdownThemes.gallery.length) %
              MarkdownThemes.gallery.length,
        );
      case LogicalKey.keyR:
        _startStream();
      case LogicalKey.keyT:
        setState(() => _agentIndex = (_agentIndex + 1) % _agents.length);
      case LogicalKey.keyQ:
        _quit();
      case LogicalKey.keyC when event.isControlPressed:
        _quit();
      default:
        return false;
    }
    return true;
  }

  Color _dim(Color c, double t) {
    final bg = _theme.background ?? const Color(0xFF000000);
    return Color.fromRGB(
      (c.red + (bg.red - c.red) * t).round().clamp(0, 255),
      (c.green + (bg.green - c.green) * t).round().clamp(0, 255),
      (c.blue + (bg.blue - c.blue) * t).round().clamp(0, 255),
    );
  }

  Color _darken(Color c, double t) {
    return Color.fromRGB(
      (c.red * (1 - t)).round().clamp(0, 255),
      (c.green * (1 - t)).round().clamp(0, 255),
      (c.blue * (1 - t)).round().clamp(0, 255),
    );
  }

  TextSpan _shimmerThinking() {
    const word = 'Thinking';
    if (_phase >= 1) {
      return TextSpan(
        text: 'Thought:',
        style: TextStyle(
          color: _dim(_theme.h1Style?.color ?? const Color(0xFFFFFFFF), 0.55),
          fontWeight: FontWeight.bold,
        ),
      );
    }
    final base = _dim(_theme.textStyle?.color ?? const Color(0xFF808080), 0.55);
    final hi = _theme.h1Style?.color ?? const Color(0xFFFFFFFF);
    final spans = <InlineSpan>[];
    for (var i = 0; i < word.length; i++) {
      final dist =
          (i - (_shimmerTick % (word.length + 4)) + word.length) %
          (word.length + 4);
      final t = dist < 3 ? 1.0 - dist / 3.0 : 0.0;
      final color = Color.fromRGB(
        (base.red + (hi.red - base.red) * t).round().clamp(0, 255),
        (base.green + (hi.green - base.green) * t).round().clamp(0, 255),
        (base.blue + (hi.blue - base.blue) * t).round().clamp(0, 255),
      );
      spans.add(
        TextSpan(
          text: word[i],
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      );
    }
    return TextSpan(children: spans);
  }

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: _onKey,
      child: Container(
        color: _theme.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
              color: _darken(_theme.background ?? const Color(0xFF000000), 0.3),
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
                    ' ${_theme.name} (${_themeIndex + 1}/${_themes.length}) ',
                    style: TextStyle(color: _theme.textStyle?.color),
                  ),
                  Expanded(child: SizedBox()),
                  Text(
                    _phase == 2 ? ' done ' : ' streaming… ',
                    style: TextStyle(
                      color: _phase == 2
                          ? _theme.textStyle?.color
                          : _agentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '  ←/→ theme · r restart · t agent · q quit ',
                    style: TextStyle(color: _theme.horizontalRuleStyle?.color),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardScrollable: true,
                padding: const EdgeInsets.all(1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_thinkingText.isNotEmpty || _phase == 0) ...[
                      RichText(text: _shimmerThinking()),
                      const SizedBox(height: 1),
                      if (_thinkingText.isNotEmpty)
                        MarkdownPlus(
                          _thinkingText,
                          theme: _theme.dimmed(factor: 0.45),
                          highlighter: const PlainHighlighter(),
                          showMarkers: false,
                        ),
                      if (_phase >= 1) const SizedBox(height: 1),
                    ],
                    if (_phase >= 1)
                      MarkdownPlus(
                        _answerText.isEmpty ? '…' : _answerText,
                        theme: _theme,
                        highlighter: const SyntaxCoreHighlighter(),
                        showMarkers: false,
                      ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _darken(
                  _theme.background ?? const Color(0xFF000000),
                  0.3,
                ),
                border: BoxBorder(
                  left: BorderSide(color: _agentColor, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _inputController,
                    focused: true,
                    readOnly: true,
                    style: TextStyle(color: _theme.textStyle?.color),
                    cursorColor: _agentColor,
                    cursorBlinkRate: const Duration(milliseconds: 500),
                    cursorStyle: CursorStyle.block,
                    placeholder: 'Ask anything…',
                    placeholderStyle: TextStyle(
                      color: _theme.horizontalRuleStyle?.color,
                    ),
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: 1),
                  RichText(text: _buildAgentLine()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildAgentLine() {
    return TextSpan(
      children: [
        TextSpan(
          text: _agents[_agentIndex],
          style: TextStyle(color: _agentColor, fontWeight: FontWeight.bold),
        ),
        TextSpan(
          text: ' · Muse Glimmer 30B · NVIDIA NIM · max',
          style: TextStyle(color: _theme.textStyle?.color),
        ),
      ],
    );
  }
}
