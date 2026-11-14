import 'package:nocterm/nocterm.dart';

import '../theme/markdown_theme.dart';

/// Renders unified diffs (`diff`/`patch` fenced blocks) with the theme's
/// diff slots: additions, removals, hunk headers, and git metadata each get
/// their own color; context lines stay in the code style.
class DiffRenderer {
  const DiffRenderer._();

  static InlineSpan render({
    required String diff,
    required MarkdownTheme theme,
    String indent = '',
  }) {
    final baseStyle = theme.codeBlockStyle ?? theme.baseTextStyle;
    final addedStyle = theme.diffAddedStyle ?? baseStyle;
    final removedStyle = theme.diffRemovedStyle ?? baseStyle;
    final hunkStyle = theme.diffHunkStyle ?? baseStyle;
    final metaStyle = theme.diffMetaStyle ?? baseStyle;

    final source = diff.endsWith('\n')
        ? diff.substring(0, diff.length - 1)
        : diff;
    final children = <InlineSpan>[];
    for (final line in source.split('\n')) {
      children.add(
        TextSpan(
          text: line,
          style: _styleFor(
            line,
            baseStyle,
            addedStyle,
            removedStyle,
            hunkStyle,
            metaStyle,
          ).toTextStyle(),
        ),
      );
      children.add(const TextSpan(text: '\n'));
    }
    // Blank line after the block, matching block-level spacing elsewhere.
    children.add(const TextSpan(text: '\n'));

    return TextSpan(
      children: [
        TextSpan(text: indent),
        ...children,
      ],
    );
  }

  static MarkdownStyle _styleFor(
    String line,
    MarkdownStyle base,
    MarkdownStyle added,
    MarkdownStyle removed,
    MarkdownStyle hunk,
    MarkdownStyle meta,
  ) {
    if (line.startsWith('diff ') ||
        line.startsWith('index ') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ') ||
        line.startsWith('\\')) {
      return meta;
    }
    if (line.startsWith('@@')) return hunk;
    if (line.startsWith('+')) return added;
    if (line.startsWith('-')) return removed;
    return base;
  }
}
