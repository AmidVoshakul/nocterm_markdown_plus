/// Syntax highlighting pipeline for `MarkdownPlus` code blocks.
library;

import '../theme/markdown_theme.dart';

/// Coarse token categories mapped onto [SyntaxTheme] slots.
enum CodeTokenType {
  plain,
  keyword,
  string,
  number,
  comment,
  function,
  variable,
  type,
  operator,
  punctuation,
}

/// A highlighted code fragment.
class CodeToken {
  /// Creates a token with the given [text] and [type].
  const CodeToken(this.text, this.type);

  /// The token text.
  final String text;

  /// The token type.
  final CodeTokenType type;
}

/// Highlights source code into per-line token lists.
///
/// Implementations must never throw for unknown input — fall back to plain
/// tokens so markdown rendering keeps working.
abstract class CodeHighlighter {
  /// Creates a highlighter.
  const CodeHighlighter();

  /// Tokenizes [code] into one token list per line.
  ///
  /// [language] is the fenced code block's info string (e.g. `dart`, `json`).
  List<List<CodeToken>> highlight(String code, {String? language});
}

/// Fallback highlighter that emits each line as a single plain token.
class PlainHighlighter extends CodeHighlighter {
  const PlainHighlighter();

  @override
  List<List<CodeToken>> highlight(String code, {String? language}) {
    final lines = code.split('\n');
    return lines
        .map((line) => [CodeToken(line, CodeTokenType.plain)])
        .toList(growable: false);
  }
}

/// Maps a [CodeTokenType] onto a slot of [SyntaxTheme] with sensible fallbacks.
MarkdownStyle? styleForToken(SyntaxTheme? theme, CodeTokenType type) {
  if (theme == null) return null;
  switch (type) {
    case CodeTokenType.keyword:
      return theme.keyword ?? theme.plain;
    case CodeTokenType.string:
      return theme.string ?? theme.plain;
    case CodeTokenType.number:
      return theme.number ?? theme.string ?? theme.plain;
    case CodeTokenType.comment:
      return theme.comment ?? theme.plain;
    case CodeTokenType.function:
      return theme.function ?? theme.keyword ?? theme.plain;
    case CodeTokenType.variable:
      return theme.variable ?? theme.plain;
    case CodeTokenType.type:
      return theme.type ?? theme.keyword ?? theme.plain;
    case CodeTokenType.operator:
      return theme.operator ?? theme.keyword ?? theme.plain;
    case CodeTokenType.punctuation:
      return theme.punctuation ?? theme.plain;
    case CodeTokenType.plain:
      return theme.plain;
  }
}
