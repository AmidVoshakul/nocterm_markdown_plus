import 'package:nocterm/nocterm.dart';

import 'highlight/code_highlighter.dart';
import 'highlight/syntax_core_highlighter.dart';
import 'parse/markdown_document.dart';
import 'render/markdown_visitor.dart';
import 'theme/markdown_theme.dart';
import 'theme/presets.dart';

/// Displays markdown-formatted text with rich, themed colors.
///
/// A superset of nocterm's built-in `MarkdownText`: theme slots per markdown
/// per-element style slots, ordered lists, task lists, styled tables,
/// conceal mode, and optional syntax highlighting for code blocks.
///
/// ```dart
/// MarkdownPlus(
///   '# Hello\n\nRender **docs** with style.',
///   theme: MarkdownThemes.catppuccinMocha,
///   showMarkers: false,
/// )
/// ```
class MarkdownPlus extends StatefulComponent {
  const MarkdownPlus(
    this.data, {
    super.key,
    this.theme,
    this.highlighter = const SyntaxCoreHighlighter(),
    this.showMarkers = true,
    this.lineNumbers = false,
    this.builders,
    this.maxWidth,
    this.ansi256 = false,
    this.textAlign = TextAlign.left,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
  });

  /// The markdown string to display.
  final String data;

  /// The theme used to style every markdown element.
  ///
  /// Defaults to [MarkdownThemes.catppuccinMocha] when omitted.
  final MarkdownTheme? theme;

  /// Per-tag render overrides (see [MarkdownPlusBuilder]).
  final Map<String, MarkdownPlusBuilder>? builders;

  /// Explicit content width; null derives it from the layout constraints.
  final int? maxWidth;

  /// Quantize theme colors to the xterm-256 palette (for apps targeting
  /// 8-bit terminals or a retro look).
  final bool ansi256;

  /// Highlighter for fenced code blocks. Defaults to
  /// [SyntaxCoreHighlighter] (TextMate grammars, theme-consistent slots);
  /// pass `const PlainHighlighter()` for unhighlighted rendering.
  final CodeHighlighter? highlighter;

  /// Whether to render markdown source markers (heading `#`, quote `│`,
  /// list bullets and ordered numbers). Task checkboxes always render —
  /// they carry state, not syntax.
  final bool showMarkers;

  /// Whether to prefix code block lines with line numbers.
  final bool lineNumbers;

  final TextAlign textAlign;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;

  @override
  State<MarkdownPlus> createState() => _MarkdownPlusState();
}

class _MarkdownPlusState extends State<MarkdownPlus> {
  final _blockCache = <String, List<InlineSpan>>{};
  List<InlineSpan> _spans = const [];
  String? _lastData;
  MarkdownTheme? _lastTheme;
  CodeHighlighter? _lastHighlighter;
  bool? _lastAnsi256;
  Map<String, MarkdownPlusBuilder>? _lastBuilders;
  bool? _lastShowMarkers;
  bool? _lastLineNumbers;
  int? _lastMaxWidth;

  List<InlineSpan> _parseMarkdown(int? maxWidth) {
    final nodes = parseDocument(component.data);
    final theme = component.theme ?? MarkdownThemes.catppuccinMocha;
    final visitor = MarkdownPlusVisitor(
      component.ansi256 ? theme.quantizedToAnsi256() : theme,
      maxWidth: maxWidth,
      showMarkers: component.showMarkers,
      highlighter: component.highlighter,
      lineNumbers: component.lineNumbers,
      builders: component.builders,
      blockCache: _blockCache,
    );
    return visitor.visitNodes(nodes);
  }

  /// Inputs baked into cached block spans: changing any of them must drop
  /// the memo cache, not just trigger a re-render.
  bool _needsCacheReset(int? maxWidth) =>
      component.showMarkers != _lastShowMarkers ||
      component.lineNumbers != _lastLineNumbers ||
      component.ansi256 != _lastAnsi256 ||
      !identical(component.builders, _lastBuilders) ||
      (component.builders?.length ?? 0) != (_lastBuilders?.length ?? 0) ||
      !identical(component.highlighter, _lastHighlighter) ||
      component.theme != _lastTheme ||
      maxWidth != _lastMaxWidth;

  bool _needsReparse(int? maxWidth) =>
      component.data != _lastData ||
      !identical(component.theme, _lastTheme) ||
      component.theme != _lastTheme ||
      !identical(component.highlighter, _lastHighlighter) ||
      component.showMarkers != _lastShowMarkers ||
      component.lineNumbers != _lastLineNumbers ||
      component.ansi256 != _lastAnsi256 ||
      !identical(component.builders, _lastBuilders) ||
      (component.builders?.length ?? 0) != (_lastBuilders?.length ?? 0) ||
      maxWidth != _lastMaxWidth;

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            component.maxWidth ??
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth.toInt()
                : null);

        if (_needsCacheReset(maxWidth)) {
          _blockCache.clear();
        }
        if (_needsReparse(maxWidth)) {
          _lastData = component.data;
          _lastTheme = component.theme;
          _lastHighlighter = component.highlighter;
          _lastAnsi256 = component.ansi256;
          _lastBuilders = component.builders;
          _lastShowMarkers = component.showMarkers;
          _lastLineNumbers = component.lineNumbers;
          _lastMaxWidth = maxWidth;
          _spans = _parseMarkdown(maxWidth);
        }

        final content = RichText(
          text: TextSpan(children: _spans),
          textAlign: component.textAlign,
          softWrap: component.softWrap,
          overflow: component.overflow,
          maxLines: component.maxLines,
        );
        final background = component.theme?.background;
        if (background == null) return content;
        return Container(color: background, child: content);
      },
    );
  }
}
