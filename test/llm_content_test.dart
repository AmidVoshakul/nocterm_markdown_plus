import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

class _Styled {
  _Styled(this.text, this.style);

  final String text;
  final TextStyle? style;
}

List<_Styled> _styledText(InlineSpan span, [TextStyle? inherited]) {
  if (span is! TextSpan) return const [];
  final style = span.style ?? inherited;
  final self = span.text == null
      ? const <_Styled>[]
      : [_Styled(span.text!, style)];
  return [
    ...self,
    for (final child in span.children ?? const <InlineSpan>[])
      ..._styledText(child, style),
  ];
}

List<_Styled> _render(String markdown, MarkdownTheme theme) {
  final spans = MarkdownPlusVisitor(theme).visitNodes(parseDocument(markdown));
  return spans.expand(_styledText).toList();
}

String _plainText(InlineSpan span) {
  if (span is! TextSpan) return '';
  return (span.text ?? '') +
      (span.children ?? const <InlineSpan>[]).map(_plainText).join();
}

MarkdownTheme get _theme => MarkdownThemes.catppuccinMocha;

void main() {
  group('alerts', () {
    test('renders a warning alert with title and icon', () {
      final text = _render('> [!WARNING]\n> Danger ahead.', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('Warning'));
      expect(flat, contains('Danger ahead.'));
      expect(text.any((s) => s.text == '⚠ '), isTrue);
    });

    test('every alert type maps to its own style', () {
      final types = {
        'NOTE': _theme.alertNoteStyle,
        'TIP': _theme.alertTipStyle,
        'IMPORTANT': _theme.alertImportantStyle,
        'WARNING': _theme.alertWarningStyle,
        'CAUTION': _theme.alertCautionStyle,
      };
      for (final entry in types.entries) {
        expect(entry.value, isNotNull, reason: entry.key);
        final text = _render('> [!${entry.key}]\n> body', _theme);
        expect(
          text.any((s) => s.style?.color == entry.value?.color),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('alert content is indented under the title', () {
      final text = _render('> [!NOTE]\n> note body', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('note body'));
      expect(flat, contains('Note'));
    });
  });

  group('footnotes', () {
    test('references render as [n] with the ref style', () {
      final text = _render('Body[^1]\n\n[^1]: note text', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('[1]'));
      expect(text.any((s) => s.text == '[1]'), isTrue);
    });

    test('definitions render in a footnotes block', () {
      final text = _render('Body[^1]\n\n[^1]: note text', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('note text'));
      expect(flat, contains('Footnotes'));
    });
  });

  group('autolinks', () {
    test('bare urls do not repeat the url in brackets', () {
      final text = _render('Visit https://example.com now', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('https://example.com'));
      expect(flat, isNot(contains('[https://example.com]')));
    });

    test('named links still show their url', () {
      final text = _render('[nocterm](https://nocterm.dev)', _theme);
      final flat = _plainTextOf(text);
      expect(flat, contains('nocterm [https://nocterm.dev]'));
    });
  });

  group('emoji shortcodes', () {
    test('renders :rocket: as the emoji glyph', () {
      final spans = MarkdownPlusVisitor(_theme)
          .visitNodes(parseDocument('Hi :rocket: there'));
      final flat = (spans).map(_plainText).join();
      expect(flat, contains('🚀'));
    });
  });

  group('malformed alerts', () {
    test('an alert div without a known type renders plain content', () {
      final element = md.Element('div', <md.Node>[md.Text('hello')])
        ..attributes['class'] = 'markdown-alert';
      final spans = MarkdownPlusVisitor(_theme).visitNodes([element]);
      final flat = spans.map(_plainText).join();
      expect(flat, contains('hello'));
      expect(flat, isNot(contains('NOTE')));
    });
  });

  group('footnote ref glyphs', () {
    test('footnoteRefStyle prefix and suffix wrap the ref', () {
      final theme = _theme.copyWith(
        footnoteRefStyle: MarkdownStyle(prefix: '\u2020', suffix: '\u2020'),
      );
      final text = _render('Body[^1]\n\n[^1]: note text', theme);
      expect(_plainTextOf(text), contains('\u2020[1]\u2020'));
    });
  });
}

String _plainTextOf(List<_Styled> spans) => spans.map((s) => s.text).join();
