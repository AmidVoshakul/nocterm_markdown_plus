import 'package:nocterm/nocterm.dart';

import '../highlight/code_highlighter.dart';
import '../theme/markdown_theme.dart';

/// Renders a fenced code block: per-line background, optional line numbers,
/// and either plain or syntax-highlighted tokens.
class CodeBlockRenderer {
  const CodeBlockRenderer._();

  static InlineSpan render({
    required String code,
    required String? language,
    required MarkdownTheme theme,
    CodeHighlighter? highlighter,
    bool lineNumbers = false,
    String indent = '',
  }) {
    final baseStyle = (theme.codeBlockStyle ?? theme.baseTextStyle);
    final bgStyle = theme.codeBlockBackgroundStyle ?? const MarkdownStyle();
    final plainStyle = bgStyle.merge(baseStyle);

    // Fenced code blocks parse with a trailing newline; dropping it keeps a
    // blank (or phantom line-numbered) line out of the output.
    final source = code.endsWith('\n')
        ? code.substring(0, code.length - 1)
        : code;
    final children = <InlineSpan>[];

    if (highlighter != null) {
      final tokenLines = _safeHighlight(highlighter, source, language);
      final sourceLines = source.split('\n');
      for (var i = 0; i < tokenLines.length; i++) {
        if (lineNumbers) {
          children.add(
            TextSpan(
              text: '${(i + 1).toString().padLeft(3)} ',
              style:
                  (theme.syntaxTheme?.comment ?? theme.textStyle ?? baseStyle)
                      .merge(bgStyle)
                      .toTextStyle(),
            ),
          );
        }
        if (tokenLines[i].isEmpty) {
          final fallback = i < sourceLines.length ? sourceLines[i] : '';
          children.add(
            TextSpan(text: fallback, style: plainStyle.toTextStyle()),
          );
        } else {
          for (final token in tokenLines[i]) {
            final tokenStyle =
                (styleForToken(theme.syntaxTheme, token.type) ?? baseStyle)
                    .merge(bgStyle);
            children.add(
              TextSpan(text: token.text, style: tokenStyle.toTextStyle()),
            );
          }
        }
        children.add(const TextSpan(text: '\n'));
      }
    } else {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final prefix = lineNumbers ? '${(i + 1).toString().padLeft(3)} ' : '';
        children.add(
          TextSpan(
            text: '$prefix${lines[i]}\n',
            style: plainStyle.toTextStyle(),
          ),
        );
      }
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

  static List<List<CodeToken>> _safeHighlight(
    CodeHighlighter highlighter,
    String code,
    String? language,
  ) {
    try {
      return highlighter.highlight(code, language: language);
    } catch (_) {
      return PlainHighlighter().highlight(code, language: language);
    }
  }
}
