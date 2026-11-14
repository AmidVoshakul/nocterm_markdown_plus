import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';

import '../highlight/code_highlighter.dart';
import '../theme/markdown_theme.dart';
import 'code_block_renderer.dart';
import '../diagram/mermaid_renderer.dart';
import 'diff_renderer.dart';
import 'table_renderer.dart';

/// Renders a single markdown tag yourself; return null to keep the default.
typedef MarkdownPlusBuilder = InlineSpan? Function(
  md.Element element,
  MarkdownPlusVisitor visitor,
);

/// Converts a markdown AST into a styled [InlineSpan] tree.
///
/// Superset of nocterm's built-in `MarkdownText` visitor: ordered-list
/// numbering, task-list checkboxes, conceal mode, per-cell styled tables,
/// themed code blocks with optional syntax highlighting.
class MarkdownPlusVisitor {
  MarkdownPlusVisitor(
    this.theme, {
    this.maxWidth,
    this.showMarkers = true,
    this.highlighter,
    this.lineNumbers = false,
    this.builders,
    this.blockCache,
  });

  final MarkdownTheme theme;
  final int? maxWidth;
  final bool showMarkers;
  final CodeHighlighter? highlighter;
  final bool lineNumbers;

  /// Per-tag render overrides, consulted before the built-in renderer.
  final Map<String, MarkdownPlusBuilder>? builders;

  /// Shared memo cache: a block's span subtree is reused while its source is
  /// unchanged (streaming renders re-render only the growing tail).
  final Map<String, List<InlineSpan>>? blockCache;

  final _listStack = <_ListState>[];

  List<InlineSpan> visitNodes(List<md.Node> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      final cached = _cachedSpansFor(node);
      if (cached != null) {
        spans.addAll(cached);
        continue;
      }
      final span = visitNode(node);
      if (span != null) {
        spans.add(span);
        blockCache?[_cacheKeyFor(node)] = [span];
      }
    }
    if (spans.isNotEmpty) {
      spans[spans.length - 1] = _trimTrailingNewlines(spans.last);
    }
    return spans;
  }

  static InlineSpan _trimTrailingNewlines(InlineSpan span) {
    if (span is! TextSpan) return span;
    final children = span.children;
    if (children != null && children.isNotEmpty) {
      final last = children.last;
      if (last is TextSpan &&
          last.text != null &&
          RegExp(r'^\n+$').hasMatch(last.text!)) {
        return TextSpan(
          children: children.sublist(0, children.length - 1),
          style: span.style,
        );
      }
      final trimmedLast = _trimTrailingNewlines(last);
      if (trimmedLast != last) {
        final updated = [...children];
        updated[updated.length - 1] = trimmedLast;
        return TextSpan(children: updated, style: span.style);
      }
    } else if (span.text != null && span.text!.endsWith('\n')) {
      return TextSpan(text: span.text!.trimRight(), style: span.style);
    }
    return span;
  }

  InlineSpan? visitNode(md.Node node) {
    if (node is md.Element) return visitElement(node);
    if (node is md.Text) return TextSpan(text: node.text);
    return null;
  }

  InlineSpan? visitChildren(md.Element element) {
    final spans = <InlineSpan>[];
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'input') continue;
      final span = visitNode(child);
      if (span != null) spans.add(span);
    }
    return spans.isEmpty ? null : TextSpan(children: spans);
  }

  TextStyle? _style(MarkdownStyle? style) => style?.toTextStyle();

  /// Wraps [child] span with the style's prefix/suffix glyphs, merging the
  /// optional [background] style.
  InlineSpan _withGlyphs(
    MarkdownStyle? style,
    InlineSpan? child, {
    MarkdownStyle? background,
  }) {
    final merged = background == null
        ? style
        : (style ?? MarkdownStyle.empty).merge(background);
    final textStyle = (merged ?? theme.baseTextStyle).toTextStyle();
    return TextSpan(
      children: [
        if (style case MarkdownStyle(prefix: final prefix?))
          TextSpan(text: prefix, style: textStyle),
        ?child,
        if (style case MarkdownStyle(suffix: final suffix?))
          TextSpan(text: suffix, style: textStyle),
      ],
      style: textStyle,
    );
  }

  InlineSpan? visitElement(md.Element element) {
    final builder = builders?[element.tag];
    if (builder != null) {
      final custom = builder(element, this);
      if (custom != null) return custom;
    }
    switch (element.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _heading(element);
      case 'p':
        return TextSpan(
          children: [
            ...childrenOf(visitChildren(element)),
            const TextSpan(text: '\n\n'),
          ],
          style: _style(theme.paragraphStyle ?? theme.textStyle),
        );
      case 'strong':
      case 'b':
        return _withGlyphs(theme.strongStyle, visitChildren(element));
      case 'em':
      case 'i':
        return _withGlyphs(theme.emphStyle, visitChildren(element));
      case 'del':
      case 's':
        return _withGlyphs(theme.delStyle, visitChildren(element));
      case 'code':
        return _withGlyphs(
          theme.codeStyle,
          TextSpan(text: element.textContent),
          background: theme.codeBackgroundStyle,
        );
      case 'pre':
        return _codeBlock(element);
      case 'blockquote':
        final bar = showMarkers ? theme.blockQuoteBarStyle?.prefix ?? '│ ' : '';
        return TextSpan(
          children: [
            if (bar.isNotEmpty)
              TextSpan(text: bar, style: _style(theme.blockQuoteBarStyle)),
            ...childrenOf(visitChildren(element)),
            const TextSpan(text: '\n'),
          ],
          style: _style(theme.blockQuoteStyle),
        );
      case 'a':
        final href = element.attributes['href'] ?? '';
        final style = theme.linkStyle;
        final isAutolink = element.textContent == href;
        return TextSpan(
          children: [
            TextSpan(text: element.textContent, style: _style(style)),
            if (!isAutolink)
              TextSpan(text: ' [$href]', style: _style(theme.linkTextStyle)),
          ],
        );
      case 'img':
        return TextSpan(
          children: [
            TextSpan(text: '[Image: ', style: _style(theme.imageStyle)),
            TextSpan(
              text: element.attributes['alt'] ?? 'image',
              style: _style(theme.imageTextStyle ?? theme.imageStyle),
            ),
            TextSpan(text: ']', style: _style(theme.imageStyle)),
          ],
        );
      case 'ul':
      case 'ol':
        return _list(element);
      case 'li':
        return _listItem(element);
      case 'hr':
        final width = maxWidth ?? 40;
        return TextSpan(
          text: theme.horizontalRuleChar * width + '\n\n',
          style: _style(theme.horizontalRuleStyle),
        );
      case 'br':
        return const TextSpan(text: '\n');
      case 'table':
        return TableRenderer.render(element, theme, this, maxWidth: maxWidth);
      case 'dl':
        return TextSpan(
          children: [
            ...childrenOf(visitChildren(element)),
            const TextSpan(text: '\n'),
          ],
        );
      case 'dt':
        return TextSpan(
          children: [
            ...childrenOf(visitChildren(element)),
            const TextSpan(text: '\n'),
          ],
          style: _style(theme.definitionTermStyle),
        );
      case 'dd':
        return TextSpan(
          children: [
            TextSpan(text: ': ', style: _style(theme.definitionListStyle)),
            ...childrenOf(visitChildren(element)),
            const TextSpan(text: '\n'),
          ],
          style: _style(theme.definitionDescriptionStyle),
        );
      case 'input':
        return null;
      case 'front_matter':
        return null;
      case 'div':
        final classes = element.attributes['class'] ?? '';
        if (classes.contains('markdown-alert')) {
          return _alert(element, classes);
        }
        return visitChildren(element);
      case 'sup':
        return _footnoteRef(element);
      case 'section':
        final classes = element.attributes['class'] ?? '';
        if (classes.contains('footnotes')) {
          return _footnoteBlock(element);
        }
        return visitChildren(element);
      default:
        return visitChildren(element);
    }
  }

  InlineSpan _heading(md.Element element) {
    final level = int.parse(element.tag.substring(1));
    final style = switch (level) {
      1 => theme.h1Style,
      2 => theme.h2Style,
      3 => theme.h3Style,
      4 => theme.h4Style,
      5 => theme.h5Style,
      _ => theme.h6Style,
    };
    final marker = showMarkers ? style?.prefix ?? '#' * level + ' ' : '';
    return TextSpan(
      children: [
        TextSpan(text: marker, style: _style(style)),
        ...childrenOf(visitChildren(element)),
        const TextSpan(text: '\n\n'),
      ],
      style: _style(style ?? theme.strongStyle),
    );
  }

  InlineSpan _list(md.Element element) {
    final ordered = element.tag == 'ol';
    final start = int.tryParse(element.attributes['start'] ?? '') ?? 1;
    _listStack.add(_ListState(ordered: ordered, counter: start - 1));
    final children = <InlineSpan>[...childrenOf(visitChildren(element))];
    _listStack.removeLast();
    if (_listStack.isEmpty) children.add(const TextSpan(text: '\n'));
    return TextSpan(children: children);
  }

  InlineSpan _listItem(md.Element element) {
    final state = _listStack.isEmpty ? null : _listStack.last;
    final depth = _listStack.isEmpty ? 1 : _listStack.length;
    final indent = '  ' * (depth - 1);
    final children = <InlineSpan>[TextSpan(text: indent)];

    final isTask = element.attributes['class'] == 'task-list-item';
    if (isTask) {
      final checked =
          element.children?.any(
            (child) =>
                child is md.Element &&
                child.tag == 'input' &&
                child.attributes['checked'] == 'true',
          ) ??
          false;
      final taskStyle = checked
          ? theme.taskCheckedStyle
          : theme.taskUncheckedStyle;
      children.add(
        TextSpan(
          text: checked
              ? taskStyle?.prefix ?? theme.taskCheckedGlyph
              : taskStyle?.prefix ?? theme.taskUncheckedGlyph,
          style: _style(taskStyle ?? theme.listBulletStyle),
        ),
      );
    } else if (state?.ordered ?? false) {
      state!.counter += 1;
      if (showMarkers) {
        children.add(
          TextSpan(
            text: '${state.counter}. ',
            style: _style(theme.listEnumerationStyle),
          ),
        );
      }
    } else if (showMarkers) {
      children.add(
        TextSpan(
          text: theme.listBulletStyle?.prefix ?? theme.bulletGlyph,
          style: _style(theme.listBulletStyle),
        ),
      );
    }

    if (element.children != null) {
      for (final child in element.children!) {
        if (child is md.Element && (child.tag == 'ul' || child.tag == 'ol')) {
          // The item's own line must end before a nested list block.
          children.add(const TextSpan(text: '\n'));
        }
        final span = visitNode(child);
        if (span != null) children.add(span);
      }
    }
    children.add(const TextSpan(text: '\n'));
    // A bare text node inside <li> carries no style of its own; without a base
    // style on this wrapper the item text falls back to the terminal default
    // (white), which is invisible on light themes.
    return TextSpan(children: children, style: _style(theme.textStyle));
  }

  InlineSpan _codeBlock(md.Element element) {
    final codeElement = element.children?.firstOrNull;
    final code = codeElement is md.Element
        ? codeElement.textContent
        : element.textContent;
    final className = codeElement is md.Element
        ? codeElement.attributes['class']
        : null;
    final language = className?.startsWith('language-') == true
        ? className!.substring(9)
        : null;

    if (language == 'mermaid') {
      return MermaidRenderer.render(
        code: code,
        theme: theme,
        maxWidth: maxWidth,
      );
    }

    if (language == 'diff' || language == 'patch') {
      return DiffRenderer.render(diff: code, theme: theme);
    }
    return CodeBlockRenderer.render(
      code: code,
      language: language,
      theme: theme,
      highlighter: highlighter,
      lineNumbers: lineNumbers,
    );
  }
}

List<InlineSpan> childrenOf(InlineSpan? span) =>
    span is TextSpan && span.children != null ? span.children! : const [];

class _ListState {
  _ListState({required this.ordered, required this.counter});

  final bool ordered;
  int counter;
}

extension _AlertRendering on MarkdownPlusVisitor {
  InlineSpan _alert(md.Element element, String classes) {
    final type = classes
        .split(' ')
        .map(
          (c) => c.startsWith('markdown-alert-')
              ? c.substring('markdown-alert-'.length)
              : '',
        )
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    // A malformed alert div without a known type renders as ordinary
    // content instead of masquerading as a note.
    if (!const {
      'note',
      'tip',
      'important',
      'warning',
      'caution',
    }.contains(type)) {
      return visitChildren(element) ?? const TextSpan(text: '');
    }
    final style = switch (type) {
      'note' => theme.alertNoteStyle,
      'tip' => theme.alertTipStyle,
      'important' => theme.alertImportantStyle,
      'warning' => theme.alertWarningStyle,
      _ => theme.alertCautionStyle,
    };
    final title =
        element.children
            ?.whereType<md.Element>()
            .where((c) => c.attributes['class'] == 'markdown-alert-title')
            .firstOrNull
            ?.textContent ??
        type;
    final body = <InlineSpan>[
      for (final child in element.children ?? const <md.Node>[])
        if (child is! md.Element ||
            child.attributes['class'] != 'markdown-alert-title')
          ?visitNode(child),
    ];
    return TextSpan(
      children: [
        TextSpan(
          text: style?.prefix ?? '${type.toUpperCase()} ',
          style: style?.toTextStyle(),
        ),
        TextSpan(
          text: '$title\n',
          style: style?.copyWith(bold: true).toTextStyle(),
        ),
        ...body,
      ],
      style: style?.toTextStyle(),
    );
  }

  InlineSpan _footnoteRef(md.Element element) {
    final number = element.textContent.trim();
    return _withGlyphs(theme.footnoteRefStyle, TextSpan(text: '[$number]'));
  }

  InlineSpan _footnoteBlock(md.Element element) {
    final style = theme.footnoteDefinitionStyle ?? theme.baseTextStyle;
    final items = <InlineSpan>[
      TextSpan(text: 'Footnotes\n', style: style.toTextStyle()),
    ];
    var index = 1;
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'ol') continue;
      for (final item in child.children ?? const <md.Node>[]) {
        if (item is! md.Element || item.tag != 'li') continue;
        items.add(
          TextSpan(
            text: '  [$index] ${item.textContent.trim()}\n',
            style: style.toTextStyle(),
          ),
        );
        index++;
      }
    }
    return TextSpan(children: items, style: style.toTextStyle());
  }
}

extension _BlockCache on MarkdownPlusVisitor {
  /// Key must distinguish block kinds: `hr` has empty textContent, a heading
  /// and a paragraph can share text, and two code blocks can carry the same
  /// code with different languages (different highlighting).
  String _cacheKeyFor(md.Node node) {
    if (node is! md.Element) return 'text:${node.textContent}';
    String? language;
    if (node.tag == 'pre') {
      final code = node.children?.whereType<md.Element>().firstOrNull;
      final className = code?.attributes['class'];
      if (className?.startsWith('language-') == true) {
        language = className!.substring(9);
      }
    }
    return '${node.tag}:${language ?? ''}:${node.textContent}';
  }

  List<InlineSpan>? _cachedSpansFor(md.Node node) =>
      blockCache?[_cacheKeyFor(node)];
}
