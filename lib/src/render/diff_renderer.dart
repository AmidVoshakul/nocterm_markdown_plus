import 'package:nocterm/nocterm.dart';

import '../highlight/code_highlighter.dart';
import '../theme/markdown_theme.dart';

/// Renders unified diffs (`diff`/`patch` fenced blocks) with the theme's
/// diff slots: additions and removals get a colored background (VS Code
/// style) with code-colored text, hunk headers and git metadata keep their
/// own colors, and context lines stay in the code style.
class DiffRenderer {
  const DiffRenderer._();

  static InlineSpan render({
    required String diff,
    required MarkdownTheme theme,
    CodeHighlighter? highlighter,
    String indent = '',
  }) {
    final baseStyle = theme.codeBlockStyle ?? theme.baseTextStyle;
    final codeColor = baseStyle.color;
    final addedBg = theme.diffAddedStyle?.background;
    final removedBg = theme.diffRemovedStyle?.background;
    final addedFg = theme.diffAddedStyle?.color ?? codeColor;
    final removedFg = theme.diffRemovedStyle?.color ?? codeColor;
    final hunkStyle = theme.diffHunkStyle ?? baseStyle;
    final metaStyle = theme.diffMetaStyle ?? baseStyle;

    final language = highlighter == null ? null : _detectLanguage(diff);

    final source = diff.endsWith('\n')
        ? diff.substring(0, diff.length - 1)
        : diff;
    final children = <InlineSpan>[];
    for (final line in source.split('\n')) {
      final kind = _classify(line);
      if (kind == _LineKind.added || kind == _LineKind.removed) {
        final bg = kind == _LineKind.added ? addedBg : removedBg;
        final fg = kind == _LineKind.added ? addedFg : removedFg;
        final marker = line.isEmpty ? '' : line.substring(0, 1);
        final content = line.length > 1 ? line.substring(1) : '';
        children.add(TextSpan(text: indent));
        children.add(
          TextSpan(
            text: marker,
            style: MarkdownStyle(color: fg, background: bg).toTextStyle(),
          ),
        );
        if (content.isNotEmpty) {
          if (highlighter != null && language != null) {
            List<List<CodeToken>> tokens;
            try {
              tokens = highlighter.highlight(content, language: language);
            } catch (_) {
              tokens = const PlainHighlighter().highlight(content);
            }
            final lineTokens = tokens.isNotEmpty
                ? tokens.first
                : const <CodeToken>[];
            if (lineTokens.isEmpty) {
              children.add(
                TextSpan(
                  text: content,
                  style: MarkdownStyle(color: fg, background: bg).toTextStyle(),
                ),
              );
            } else {
              for (final token in lineTokens) {
                final style = styleForToken(theme.syntaxTheme, token.type);
                children.add(
                  TextSpan(
                    text: token.text,
                    style: (style ?? MarkdownStyle.empty)
                        .copyWith(
                          color: style?.color ?? fg,
                          background: bg,
                          bold: style?.bold ?? false,
                          italic: style?.italic ?? false,
                        )
                        .toTextStyle(),
                  ),
                );
              }
            }
          } else {
            children.add(
              TextSpan(
                text: content,
                style: MarkdownStyle(color: fg, background: bg).toTextStyle(),
              ),
            );
          }
        }
        children.add(const TextSpan(text: '\n'));
      } else {
        children.add(
          TextSpan(
            text: '$indent$line\n',
            style: _styleFor(
              line,
              baseStyle,
              hunkStyle,
              metaStyle,
            ).toTextStyle(),
          ),
        );
      }
    }
    // Blank line after the block, matching block-level spacing elsewhere.
    children.add(const TextSpan(text: '\n'));

    return TextSpan(children: children);
  }

  static _LineKind _classify(String line) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      return _LineKind.added;
    }
    if (line.startsWith('-') && !line.startsWith('---')) {
      return _LineKind.removed;
    }
    return _LineKind.other;
  }

  static MarkdownStyle _styleFor(
    String line,
    MarkdownStyle base,
    MarkdownStyle hunk,
    MarkdownStyle meta,
  ) {
    if (line.startsWith('diff ') ||
        line.startsWith('index ') ||
        line.startsWith('---') ||
        line.startsWith('+++') ||
        line.startsWith('\\')) {
      return meta;
    }
    if (line.startsWith('@@')) return hunk;
    return base;
  }

  static String? _detectLanguage(String diff) {
    // Prefer the new-file path from "+++ b/..." or "diff --git a/X b/X".
    String? path;
    for (final line in diff.split('\n')) {
      if (line.startsWith('+++ ')) {
        final candidate = line.substring(4).trim();
        if (candidate != '/dev/null') {
          path = candidate.startsWith('b/')
              ? candidate.substring(2)
              : candidate;
          break;
        }
      }
    }
    if (path == null) {
      for (final line in diff.split('\n')) {
        if (line.startsWith('diff --git ')) {
          final parts = line.split(' ');
          if (parts.length >= 4) {
            path = parts[3];
            if (path.startsWith('b/')) path = path.substring(2);
          }
          break;
        }
      }
    }
    if (path == null) return null;
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    const map = {
      'dart': 'dart',
      'js': 'javascript',
      'jsx': 'javascript',
      'mjs': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'py': 'python',
      'go': 'go',
      'rs': 'rust',
      'kt': 'kotlin',
      'swift': 'swift',
      'json': 'json',
      'jsonc': 'jsonc',
      'yml': 'yaml',
      'yaml': 'yaml',
      'md': 'markdown',
      'css': 'css',
      'html': 'html',
      'htm': 'html',
      'sh': 'shellscript',
      'bash': 'shellscript',
      'sql': 'sql',
      'xml': 'xml',
    };
    return map[ext];
  }
}

enum _LineKind { added, removed, other }
