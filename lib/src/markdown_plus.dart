import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';

import 'highlight/code_highlighter.dart';
import 'highlight/syntax_core_highlighter.dart';
import 'parse/markdown_document.dart';
import 'render/markdown_visitor.dart';
import 'render/image_block.dart';
import 'theme/markdown_theme.dart';
import 'theme/no_color.dart';
import 'theme/presets.dart';

enum _RebuildKind { none, reparse, reset }

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
    this.showListMarkers = true,
    this.lineNumbers = false,
    this.builders,
    this.maxWidth,
    this.renderImages = true,
    this.imageMaxWidth = 40,
    this.imageProtocol = ImageProtocol.unicodeBlocks,
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

  /// Whether markdown images are rendered as real terminal images. When
  /// false, every image falls back to the `[Image: alt]` placeholder.
  final bool renderImages;

  /// Maximum width (in cells) for a rendered image. Larger source images
  /// are scaled down to fit.
  final int? imageMaxWidth;

  /// Preferred image protocol; null auto-detects the best one.
  final ImageProtocol? imageProtocol;

  /// Quantize theme colors to the xterm-256 palette (for apps targeting
  /// 8-bit terminals or a retro look).
  final bool ansi256;

  /// Highlighter for fenced code blocks. Defaults to
  /// [SyntaxCoreHighlighter] (TextMate grammars, theme-consistent slots);
  /// pass `const PlainHighlighter()` for unhighlighted rendering.
  final CodeHighlighter? highlighter;

  /// Whether to render markdown source markers (heading `#`, quote `│`).
  /// List bullets/numbers are controlled separately by [showListMarkers].
  /// Task checkboxes always render — they carry state, not syntax.
  final bool showMarkers;

  /// Whether to render list bullets and ordered numbers.
  final bool showListMarkers;

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
  List<_Block> _blocks = const [];
  String? _lastData;
  MarkdownTheme? _lastTheme;
  CodeHighlighter? _lastHighlighter;
  bool? _lastAnsi256;
  Map<String, MarkdownPlusBuilder>? _lastBuilders;
  bool? _lastShowMarkers;
  bool? _lastShowListMarkers;
  bool? _lastLineNumbers;
  int? _lastMaxWidth;
  bool? _lastRenderImages;
  int? _lastImageMaxWidth;
  ImageProtocol? _lastImageProtocol;
  bool? _lastNoColor;

  List<_Block> _parseBlocks(int? maxWidth) {
    final nodes = parseDocument(component.data);
    final theme = component.theme ?? MarkdownThemes.catppuccinMocha;
    final effectiveTheme = component.ansi256
        ? theme.quantizedToAnsi256()
        : theme;
    final visitor = MarkdownPlusVisitor(
      effectiveTheme,
      maxWidth: maxWidth,
      showMarkers: component.showMarkers,
      showListMarkers: component.showListMarkers,
      highlighter: component.highlighter,
      lineNumbers: component.lineNumbers,
      builders: component.builders,
      blockCache: _blockCache,
    );
    final blocks = <_Block>[];
    for (final node in nodes) {
      if (component.renderImages && component.builders?['img'] == null) {
        final img = _standaloneImage(node);
        if (img != null) {
          final src = img.attributes['src'] ?? '';
          blocks.add(
            _ImageBlock(
              src: src,
              alt: img.attributes['alt'],
              width: component.imageMaxWidth,
              protocol: component.imageProtocol,
              theme: effectiveTheme,
            ),
          );
          continue;
        }
      }
      final spans = visitor.visitBlock(node);
      if (spans != null && spans.isNotEmpty) {
        blocks.add(_TextBlock(spans));
      }
    }
    if (blocks.isNotEmpty && blocks.last is _TextBlock) {
      final last = blocks.last as _TextBlock;
      blocks[blocks.length - 1] = _TextBlock(<InlineSpan>[
        ...last.spans.sublist(0, last.spans.length - 1),
        MarkdownPlusVisitor.trimTrailingNewlines(last.spans.last),
      ]);
    }
    return blocks;
  }

  static md.Element? _standaloneImage(md.Node node) {
    if (node is! md.Element || node.tag != 'p') return null;
    final children = (node.children ?? const <md.Node>[])
        .where((c) => !(c is md.Text && c.text.trim().isEmpty))
        .toList();
    if (children.length != 1) return null;
    final c = children.first;
    if (c is! md.Element || c.tag != 'img') return null;
    return c;
  }

  /// Single source of truth for cache/reparse decisions. Cache-affecting
  /// inputs (theme, markers, builders, NO_COLOR, width, ...) force a cache
  /// reset; a data-only change only re-parses and may reuse cached blocks.
  _RebuildKind _classifyRebuild(int? maxWidth) {
    final cacheAffectingChanged =
        component.showMarkers != _lastShowMarkers ||
        component.showListMarkers != _lastShowListMarkers ||
        component.lineNumbers != _lastLineNumbers ||
        component.ansi256 != _lastAnsi256 ||
        !identical(component.builders, _lastBuilders) ||
        (component.builders?.length ?? 0) != (_lastBuilders?.length ?? 0) ||
        !identical(component.highlighter, _lastHighlighter) ||
        component.theme != _lastTheme ||
        maxWidth != _lastMaxWidth ||
        component.renderImages != _lastRenderImages ||
        component.imageMaxWidth != _lastImageMaxWidth ||
        component.imageProtocol != _lastImageProtocol ||
        NoColor.enabled != _lastNoColor;
    final dataChanged = component.data != _lastData;
    if (!dataChanged && !cacheAffectingChanged) return _RebuildKind.none;
    return cacheAffectingChanged ? _RebuildKind.reset : _RebuildKind.reparse;
  }

  @override
  Component build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            component.maxWidth ??
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth.toInt()
                : null);

        final decision = _classifyRebuild(maxWidth);
        if (decision == _RebuildKind.reset) {
          _blockCache.clear();
        }
        if (decision != _RebuildKind.none) {
          _lastData = component.data;
          _lastTheme = component.theme;
          _lastHighlighter = component.highlighter;
          _lastAnsi256 = component.ansi256;
          _lastBuilders = component.builders;
          _lastShowMarkers = component.showMarkers;
          _lastShowListMarkers = component.showListMarkers;
          _lastLineNumbers = component.lineNumbers;
          _lastMaxWidth = maxWidth;
          _lastRenderImages = component.renderImages;
          _lastImageMaxWidth = component.imageMaxWidth;
          _lastImageProtocol = component.imageProtocol;
          _lastNoColor = NoColor.enabled;
          _blocks = _parseBlocks(maxWidth);
        }

        final theme = component.theme ?? MarkdownThemes.catppuccinMocha;
        final effectiveTheme = component.ansi256
            ? theme.quantizedToAnsi256()
            : theme;
        // Group consecutive text blocks into a single RichText so the
        // original inter-block spacing (one blank line) is preserved; images
        // stay separate components because nocterm has no WidgetSpan.
        final children = <Component>[];
        final pending = <InlineSpan>[];
        void flushText() {
          if (pending.isEmpty) return;
          children.add(
            RichText(
              text: TextSpan(children: List.of(pending)),
              textAlign: component.textAlign,
              softWrap: component.softWrap,
              overflow: component.overflow,
              maxLines: component.maxLines,
            ),
          );
          pending.clear();
        }

        for (final block in _blocks) {
          if (block is _TextBlock) {
            pending.addAll(block.spans);
          } else if (block is _ImageBlock) {
            flushText();
            children.add(
              buildMarkdownImage(
                src: block.src,
                alt: block.alt,
                width: block.width,
                protocol: block.protocol,
                theme: effectiveTheme,
              ),
            );
            children.add(const SizedBox(height: 1));
          }
        }
        flushText();
        if (children.isEmpty) {
          children.add(const SizedBox.shrink());
        }
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
        final background = NoColor.resolve(component.theme?.background);
        if (background == null) return content;
        return Container(color: background, child: content);
      },
    );
  }
}

sealed class _Block {}

class _TextBlock extends _Block {
  _TextBlock(this.spans);
  final List<InlineSpan> spans;
}

class _ImageBlock extends _Block {
  _ImageBlock({
    required this.src,
    this.alt,
    this.width,
    this.protocol,
    this.theme,
  });
  final String src;
  final String? alt;
  final int? width;
  final ImageProtocol? protocol;
  final MarkdownTheme? theme;
}
