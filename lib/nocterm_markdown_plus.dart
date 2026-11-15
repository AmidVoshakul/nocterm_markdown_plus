/// Themed markdown rendering for nocterm — rich color themes, styled
/// tables, task lists, and syntax-highlighted code blocks.
///
/// ```dart
/// import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
///
/// MarkdownPlus(
///   '# Title\n\nSome **bold** text with `code`.',
///   theme: MarkdownThemes.nord,
/// )
/// ```

library;

export 'src/highlight/code_highlighter.dart'
    show
        CodeHighlighter,
        PlainHighlighter,
        CodeToken,
        CodeTokenType,
        styleForToken;
export 'src/highlight/syntax_core_highlighter.dart' show SyntaxCoreHighlighter;
export 'src/markdown_plus.dart' show MarkdownPlus;
export 'src/parse/markdown_document.dart' show parseDocument;
export 'src/render/markdown_visitor.dart'
    show MarkdownPlusBuilder, MarkdownPlusVisitor;
export 'src/theme/markdown_theme.dart'
    show AdaptiveMarkdownTheme, MarkdownStyle, MarkdownTheme, SyntaxTheme;
export 'src/theme/no_color.dart' show NoColor;
export 'src/theme/presets.dart' show MarkdownThemes;
