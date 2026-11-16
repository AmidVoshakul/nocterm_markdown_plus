import 'package:nocterm/nocterm.dart' hide isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('styleForToken', () {
    test('falls back through syntax slots', () {
      final theme = SyntaxTheme(
        plain: const MarkdownStyle(color: Color(0xFF111111)),
        string: const MarkdownStyle(color: Color(0xFF222222)),
        keyword: const MarkdownStyle(color: Color(0xFF333333)),
      );
      expect(
        styleForToken(theme, CodeTokenType.number)?.color,
        const Color(0xFF222222),
      );
      expect(
        styleForToken(theme, CodeTokenType.comment)?.color,
        const Color(0xFF111111),
      );
      expect(
        styleForToken(theme, CodeTokenType.variable)?.color,
        const Color(0xFF111111),
      );
      expect(
        styleForToken(theme, CodeTokenType.operator)?.color,
        const Color(0xFF333333),
      );
      expect(styleForToken(null, CodeTokenType.plain), isNull);
    });
  });

  group('SyntaxCoreHighlighter', () {
    const highlighter = SyntaxCoreHighlighter();

    test('tokenizes dart into non-plain slots', () {
      final lines = highlighter.highlight(
        "void main() {\n  final greeting = 'hi';\n}",
        language: 'dart',
      );
      final types = lines.expand((line) => line).map((t) => t.type).toSet();
      expect(types, contains(CodeTokenType.keyword));
      expect(types, contains(CodeTokenType.string));
      expect(types, contains(CodeTokenType.function));
      expect(types, contains(CodeTokenType.operator));
    });

    test('json values, keys and numbers map to slots', () {
      // `"hi"` is a string value; `"a"` is a property name (support.type).
      final stringLines = highlighter.highlight(
        '{"a": "hi"}',
        language: 'json',
      );
      final stringTypes = stringLines
          .expand((line) => line)
          .map((t) => t.type)
          .toSet();
      expect(stringTypes, contains(CodeTokenType.string));
      expect(stringTypes, contains(CodeTokenType.type));

      final numberLines = highlighter.highlight('{"a": 42}', language: 'json');
      final numberTypes = numberLines
          .expand((line) => line)
          .map((t) => t.type)
          .toSet();
      expect(numberTypes, contains(CodeTokenType.number));
    });

    test('interpolated expressions are variables, not strings', () {
      // Regression: scope-stack iteration must be innermost-first, otherwise
      // `$name` picks up the enclosing string scope.
      final lines = highlighter.highlight(
        "final s = 'hi \$name';",
        language: 'dart',
      );
      final names = lines
          .expand((line) => line)
          .where((t) => t.text.contains('name'))
          .toList();
      expect(names, isNotEmpty);
      for (final token in names) {
        expect(token.type, isNot(CodeTokenType.string));
      }
      final types = lines.expand((line) => line).map((t) => t.type).toSet();
      expect(types, contains(CodeTokenType.variable));
    });

    test('falls back to plain for unknown languages', () {
      final lines = highlighter.highlight('???', language: 'brainfuck');
      expect(lines.single.single.type, CodeTokenType.plain);
    });

    test('falls back to plain without a language', () {
      final lines = highlighter.highlight('just text');
      expect(lines.single.single.type, CodeTokenType.plain);
    });

    test('highlighted code still renders through MarkdownPlus', () async {
      await testNocterm('highlighted code renders', (tester) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '```dart\nvoid main() {}\n```',
            theme: MarkdownThemes.nord,
            highlighter: highlighter,
          ),
        );
        expect(tester.terminalState, containsText('void main() {}'));
      });
    });
  });
}
