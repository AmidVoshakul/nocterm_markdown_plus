import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

MarkdownTheme get _theme => MarkdownThemes.catppuccinMocha;

List<InlineSpan> _spans(String markdown, {CodeHighlighter? highlighter}) {
  final visitor = MarkdownPlusVisitor(_theme, highlighter: highlighter);
  return visitor.visitNodes(parseDocument(markdown));
}

bool _hasColor(InlineSpan span) {
  if (span is! TextSpan) return false;
  final style = span.style;
  if (style?.color != null || style?.backgroundColor != null) return true;
  return (span.children ?? const <InlineSpan>[]).any(_hasColor);
}

void main() {
  tearDown(() {
    NoColor.setOverride(null);
  });

  group('NoColor.enabledIn', () {
    test('absent or empty -> disabled', () {
      expect(NoColor.enabledIn(const {}), isFalse);
      expect(NoColor.enabledIn(const {'NO_COLOR': ''}), isFalse);
    });
    test('any non-empty value -> enabled (including "0")', () {
      expect(NoColor.enabledIn(const {'NO_COLOR': '0'}), isTrue);
      expect(NoColor.enabledIn(const {'NO_COLOR': '1'}), isTrue);
    });
  });

  group('MarkdownStyle.toTextStyle', () {
    test('drops color and background when enabled', () {
      NoColor.setOverride(true);
      final style = MarkdownStyle(
        color: Color(0xFFFF0000),
        background: Color(0xFF00FF00),
        bold: true,
      ).toTextStyle();
      expect(style.color, isNull);
      expect(style.backgroundColor, isNull);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('keeps color and background when disabled', () {
      NoColor.setOverride(false);
      final style = MarkdownStyle(
        color: Color(0xFFFF0000),
        background: Color(0xFF00FF00),
      ).toTextStyle();
      expect(style.color, Color(0xFFFF0000));
      expect(style.backgroundColor, Color(0xFF00FF00));
    });
  });

  group('rendering', () {
    test('colors present when disabled', () {
      NoColor.setOverride(false);
      final spans = _spans('# Title\n\n**bold** and `code`');
      expect(spans.any(_hasColor), isTrue);
    });

    test('no colors when enabled', () {
      NoColor.setOverride(true);
      final spans = _spans('# Title\n\n**bold** and `code`');
      expect(spans.any(_hasColor), isFalse);
    });

    test('diff backgrounds are dropped when enabled', () {
      NoColor.setOverride(true);
      final spans = _spans('```diff\n+ added\n- removed\n```');
      expect(spans.any(_hasColor), isFalse);
    });

    test('syntax token colors are dropped when enabled', () {
      NoColor.setOverride(true);
      final spans = _spans(
        '```dart\nvoid main() {}\n```',
        highlighter: const SyntaxCoreHighlighter(),
      );
      expect(spans.any(_hasColor), isFalse);
    });
  });

  group('painted output', () {
    test('NO_COLOR leaves text in terminal default', () {
      NoColor.setOverride(true);
      final spans = _spans('# Title\n\nHello');
      final root = TextSpan(children: spans);
      final segments = root.toStyledSegments();
      for (final seg in segments) {
        expect(seg.style?.color, isNull);
        expect(seg.style?.backgroundColor, isNull);
      }
    });
  });
}
