import 'package:syntax_core/langs/all.dart' show bundledLanguages;
import 'package:syntax_core/syntax.dart';

import 'code_highlighter.dart';

/// Highlights fenced code blocks using TextMate grammars via
/// [syntax_core] (pure Dart, VS Code/Shiki parity).
///
/// Tokens are mapped onto [CodeTokenType] slots so colors come from the
/// markdown theme's `SyntaxTheme` — code blocks stay visually consistent
/// with the active markdown theme. Unknown languages and highlighter
/// failures fall back to plain tokens, so rendering never throws.
class SyntaxCoreHighlighter extends CodeHighlighter {
  const SyntaxCoreHighlighter();

  static final Highlighter _highlighter = Highlighter(
    languages: bundledLanguages.values,
  );

  @override
  List<List<CodeToken>> highlight(String code, {String? language}) {
    if (language == null || language.isEmpty) {
      return const PlainHighlighter().highlight(code);
    }
    try {
      final grammar = _highlighter.grammar(language);
      final result = <List<CodeToken>>[];
      StateStack? state;
      for (final line in splitLines(code)) {
        final tokenized = grammar.tokenizeLine(line, state);
        result.add(
          tokenized.tokens
              .map(
                (token) => CodeToken(
                  line.substring(token.start, token.end),
                  _typeForScopes(token.scopes),
                ),
              )
              .toList(growable: false),
        );
        state = tokenized.endState;
      }
      return result;
    } catch (_) {
      return const PlainHighlighter().highlight(code);
    }
  }

  static CodeTokenType _typeForScopes(ScopeStack stack) {
    // scopes[0] is the innermost scope, so iterating directly checks the
    // most specific match first (e.g. `$name` inside an interpolated string
    // is a variable, not a string).
    final scopes = <String>[];
    ScopeStack? current = stack;
    while (current != null) {
      scopes.add(current.scope);
      current = current.parent;
    }
    for (final scope in scopes) {
      if (scope.contains('comment')) return CodeTokenType.comment;
      if (scope.contains('string')) return CodeTokenType.string;
      if (scope.contains('constant.numeric') ||
          scope.contains('constant.character') ||
          scope.contains('constant.language')) {
        return CodeTokenType.number;
      }
      if (scope.contains('entity.name.type') ||
          scope.contains('support.type') ||
          scope.contains('entity.name.class') ||
          scope.contains('support.class')) {
        return CodeTokenType.type;
      }
      if (scope.contains('entity.name.function') ||
          scope.contains('support.function') ||
          scope.contains('meta.function-call')) {
        return CodeTokenType.function;
      }
      if (scope.contains('variable.parameter') ||
          scope.contains('variable.other')) {
        return CodeTokenType.variable;
      }
      if (scope.contains('keyword.operator')) return CodeTokenType.operator;
      if (scope.contains('punctuation')) return CodeTokenType.punctuation;
      if (scope.contains('keyword') || scope.contains('storage')) {
        return CodeTokenType.keyword;
      }
    }
    return CodeTokenType.plain;
  }
}
