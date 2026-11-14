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

MarkdownTheme get _theme => MarkdownThemes.catppuccinMocha;

void main() {
  group('MarkdownStyle glyphs and layout', () {
    test('carries prefix and suffix', () {
      const style = MarkdownStyle(prefix: '> ', suffix: ' <');
      final restored = MarkdownStyle.fromJson(style.toJson());
      expect(restored, style);
      expect(style.copyWith(prefix: '* ').prefix, '* ');
    });
  });

  group('themed markdown slots', () {
    test('every preset fills the new slots', () {
      for (final theme in MarkdownThemes.gallery) {
        expect(
          theme.taskCheckedStyle,
          isNotNull,
          reason: '${theme.name} taskChecked',
        );
        expect(
          theme.taskUncheckedStyle,
          isNotNull,
          reason: '${theme.name} taskUnchecked',
        );
        expect(
          theme.imageTextStyle,
          isNotNull,
          reason: '${theme.name} imageText',
        );
        expect(
          theme.definitionListStyle,
          isNotNull,
          reason: '${theme.name} definitionList',
        );
        expect(
          theme.definitionTermStyle,
          isNotNull,
          reason: '${theme.name} definitionTerm',
        );
        expect(
          theme.definitionDescriptionStyle,
          isNotNull,
          reason: '${theme.name} definitionDescription',
        );
      }
    });

    test('ascii fallback theme is colorless and marker-based', () {
      final ascii = MarkdownThemes.ascii;
      expect(ascii.brightness, Brightness.dark);
      expect(ascii.textStyle?.color, isNull);
      expect(ascii.h1Style?.color, isNull);
      expect(ascii.codeStyle?.color, isNull);
      expect(ascii.bulletGlyph, '* ');
      expect(ascii.horizontalRuleChar, '-');
      expect(ascii.h1Style?.prefix, '# ');
      // Markers stay on so output reads like source.
      expect(ascii.strongStyle?.prefix, '**');
      expect(ascii.codeStyle?.prefix, '`');
    });

    test('list glyphs come from the style prefix', () {
      final theme = _theme.copyWith(
        listBulletStyle: const MarkdownStyle(prefix: '→ '),
      );
      final text = _render('- item', theme);
      expect(text.any((s) => s.text == '→ '), isTrue);
    });

    test('task glyphs come from the task styles', () {
      final theme = _theme.copyWith(
        taskCheckedStyle: const MarkdownStyle(prefix: '[x] '),
        taskUncheckedStyle: const MarkdownStyle(prefix: '[ ] '),
      );
      final text = _render('- [x] done\n- [ ] todo', theme);
      expect(text.any((s) => s.text == '[x] '), isTrue);
      expect(text.any((s) => s.text == '[ ] '), isTrue);
    });

    test('definition lists parse and render', () {
      final text = _render('term\n: description', _theme);
      expect(text.any((s) => s.text.contains('term')), isTrue);
      expect(text.any((s) => s.text == ': '), isTrue);
      expect(text.any((s) => s.text.contains('description')), isTrue);
    });

    test('definition term takes the term style', () {
      final text = _render('term\n: description', _theme);
      final termColor = _theme.definitionTermStyle?.color;
      expect(
        text.any((s) => s.style?.color == termColor && termColor != null),
        isTrue,
      );
    });

    test('quote bar comes from the bar style prefix', () {
      final theme = _theme.copyWith(
        blockQuoteBarStyle: const MarkdownStyle(prefix: '▌'),
      );
      final text = _render('> quoted', theme);
      expect(text.any((s) => s.text == '▌'), isTrue);
    });
  });
}
