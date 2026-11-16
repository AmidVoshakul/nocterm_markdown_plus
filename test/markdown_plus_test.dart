import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

MarkdownPlus _md(
  String data, {
  MarkdownTheme? theme,
  bool showMarkers = true,
  bool showListMarkers = true,
  bool lineNumbers = false,
  Map<String, MarkdownPlusBuilder>? builders,
  int? maxWidth,
}) {
  return MarkdownPlus(
    data,
    theme: theme,
    showMarkers: showMarkers,
    showListMarkers: showListMarkers,
    lineNumbers: lineNumbers,
    builders: builders,
    maxWidth: maxWidth,
  );
}

void main() {
  group('MarkdownPlus', () {
    test('renders plain text', () async {
      await testNocterm('renders plain text', (tester) async {
        await tester.pumpComponent(_md('This is plain text'));
        expect(tester.terminalState, containsText('This is plain text'));
      });
    });

    test('renders inline styles', () async {
      await testNocterm('renders inline styles', (tester) async {
        await tester.pumpComponent(
          _md('This is **bold**, *italic*, ~~gone~~ text'),
        );
        expect(tester.terminalState, containsText('This is bold'));
        expect(tester.terminalState, containsText('italic'));
        expect(tester.terminalState, containsText('gone'));
      });
    });

    test('conceal mode hides list markers', () async {
      await testNocterm('conceal mode hides list markers', (tester) async {
        await tester.pumpComponent(
          _md(
            '- [x] done\n- [ ] todo\n1. first\n2. second',
            showMarkers: false,
            showListMarkers: false,
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('done'));
        expect(text, contains('todo'));
        expect(text, isNot(contains('•')));
        expect(text, isNot(contains('1.')));
        // Checkboxes are rendered state, not syntax — they stay.
        expect(text, contains('\u2611'));
        expect(text, contains('\u2610'));
      });
    });

    test('renders headings with and without markers', () async {
      await testNocterm('renders headings with and without markers', (
        tester,
      ) async {
        await tester.pumpComponent(_md('# Title\n\nBody'));
        expect(tester.terminalState, containsText('# Title'));

        await tester.pumpComponent(_md('# Title\n\nBody', showMarkers: false));
        expect(tester.terminalState, containsText('Title'));
        expect(tester.terminalState, isNot(containsText('# Title')));
      });
    });

    test('renders unordered lists', () async {
      await testNocterm('renders unordered lists', (tester) async {
        await tester.pumpComponent(_md('- one\n- two\n- three'));
        final lines = tester.terminalState.getText().split('\n');
        expect(lines.where((l) => l.contains('one')).isNotEmpty, isTrue);
        expect(lines.where((l) => l.contains('two')).isNotEmpty, isTrue);
      });
    });

    test('renders ordered lists with numbering', () async {
      await testNocterm('renders ordered lists with numbering', (tester) async {
        await tester.pumpComponent(_md('3. three\n4. four'));
        final state = tester.terminalState.getText();
        expect(state.contains('3. three'), isTrue);
        expect(state.contains('4. four'), isTrue);
      });
    });

    test('renders nested ordered lists', () async {
      await testNocterm('renders nested ordered lists', (tester) async {
        await tester.pumpComponent(_md('1. outer\n   1. inner\n2. last'));
        final state = tester.terminalState.getText();
        expect(state.contains('outer'), isTrue);
        expect(state.contains('inner'), isTrue);
        expect(state.contains('last'), isTrue);
      });
    });

    test('indents nested list items', () async {
      await testNocterm('indents nested list items', (tester) async {
        await tester.pumpComponent(_md('- outer\n  - inner'));
        final lines = tester.terminalState.getText().split('\n');
        final inner = lines.firstWhere((l) => l.contains('inner'));
        // The nested bullet must be indented — its column > the outer one.
        expect(
          inner.indexOf('inner'),
          greaterThan(
            lines.firstWhere((l) => l.contains('outer')).indexOf('outer'),
          ),
        );
      });
    });

    test('renders task lists as checkboxes', () async {
      await testNocterm('renders task lists as checkboxes', (tester) async {
        await tester.pumpComponent(_md('- [x] done\n- [ ] todo'));
        final state = tester.terminalState.getText();
        expect(state.contains('done'), isTrue);
        expect(state.contains('todo'), isTrue);
        expect(state.contains('\u2611'), isTrue);
        expect(state.contains('\u2610'), isTrue);
      });
    });

    test('renders inline code and code blocks', () async {
      await testNocterm('renders inline code and code blocks', (tester) async {
        await tester.pumpComponent(
          _md('Use `dart run` here.\n\n```dart\nvoid main() {}\n```'),
        );
        expect(tester.terminalState, containsText('dart run'));
        expect(tester.terminalState, containsText('void main() {}'));
      });
    });

    test('code blocks leave a blank line and no phantom lines', () async {
      await testNocterm('code blocks leave a blank line and no phantom lines', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md('```dart\nvoid main() {}\n```', lineNumbers: true),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('void main() {}'));
        // No phantom line-number row beyond the code's own lines.
        expect(text, isNot(contains('\n2 ')));
      });
    });

    test('renders blockquote', () async {
      await testNocterm('renders blockquote', (tester) async {
        await tester.pumpComponent(_md('> quoted wisdom'));
        expect(tester.terminalState, containsText('quoted wisdom'));
      });
    });

    test('renders horizontal rule', () async {
      await testNocterm('renders horizontal rule', (tester) async {
        await tester.pumpComponent(_md('above\n\n---\n\nbelow'));
        final state = tester.terminalState.getText();
        expect(state.contains('─' * 10), isTrue);
      });
    });

    test('renders links', () async {
      await testNocterm('renders links', (tester) async {
        await tester.pumpComponent(_md('[nocterm](https://nocterm.dev)'));
        expect(tester.terminalState, containsText('nocterm'));
        expect(tester.terminalState, containsText('https://nocterm.dev'));
      });
    });

    test('renders images as placeholder', () async {
      await testNocterm('renders images as placeholder', (tester) async {
        await tester.pumpComponent(_md('![alt text](img.png)'));
        expect(tester.terminalState, containsText('[Image: alt text]'));
      });
    });

    test('separates every table row', () async {
      await testNocterm('separates every table row', (tester) async {
        await tester.pumpComponent(
          _md('''
| a | b |
|---|---|
| 1 | 2 |
| 3 | 4 |
'''),
        );
        final text = tester.terminalState.getText();
        final separators = text
            .split('\n')
            .where((l) => l.contains('├') && l.contains('┼'))
            .length;
        // One per boundary: header|row1 and row1|row2.
        expect(separators, 2);
        expect(text.contains('└'), isTrue);
      });
    });

    test('renders inline markdown inside cells', () async {
      await testNocterm('renders inline markdown inside cells', (tester) async {
        await tester.pumpComponent(
          _md('''
| key | value |
|-----|-------|
| **bold** | `code` |
'''),
        );
        final text = tester.terminalState.getText();
        expect(text.contains('bold'), isTrue);
        expect(text.contains('code'), isTrue);
      });
    });

    test('honors column alignment from the delimiter row', () async {
      await testNocterm('honors column alignment from the delimiter row', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md('''
| left | right | center |
|:-----|------:|:------:|
| a | b | c |
'''),
        );
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.firstWhere((l) => l.contains('│ a '));
        // 'a' hugs the left border of the left-aligned column.
        expect(row.indexOf('a'), lessThan(row.indexOf('b')));
      });
    });

    test('right-aligned column pads on the left', () async {
      await testNocterm('right-aligned column pads on the left', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md('''
| a | b |
|----:|----:|
| x | y |
'''),
        );
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.firstWhere((l) => l.contains('\u2502 x '));
        expect(row.indexOf('x'), greaterThan(row.indexOf('\u2502')));
      });
    });

    test('very narrow maxWidth keeps grid shape', () {
      final table = md.Element('table', [
        md.Element('thead', [
          _tr(['Name', 'Role']),
        ]),
        md.Element('tbody', [
          _tr(['amid', 'dev']),
        ]),
      ]);
      final span = MarkdownPlusVisitor(
        MarkdownThemes.nord,
        maxWidth: 8,
      ).visitElement(table);
      expect(span, isNotNull);
      final text = _plainText(span!);
      expect(text, contains('ami'));
      expect(text, contains('dev'));
    });

    test('overlong word is broken across lines', () async {
      await testNocterm('overlong word is broken across lines', (tester) async {
        await tester.pumpComponent(
          _md('''
| col |
|-----|
| supercalifragilisticexpialidocious |
''', maxWidth: 12),
        );
        final text = tester.terminalState.getText();
        expect(text.contains('super'), isTrue);
        final rows = text.split('\n').where((l) => l.contains('\u2502')).length;
        expect(rows, greaterThan(2));
      });
    });

    test('renders GFM tables with all cells', () async {
      await testNocterm('renders GFM tables with all cells', (tester) async {
        await tester.pumpComponent(
          _md('''
| name | role |
|------|------|
| amid | author |
'''),
        );
        final state = tester.terminalState.getText();
        expect(state.contains('name'), isTrue);
        expect(state.contains('amid'), isTrue);
        expect(state.contains('role'), isTrue);
        expect(state.contains('│'), isTrue);
      });
    });

    test('delimiter rows never inflate columns', () {
      // Hand-built AST: a delimiter-looking row inside tbody (some parser
      // paths emit it) must not widen the table.
      final table = md.Element('table', [
        md.Element('thead', [
          _tr(['Name', 'Role']),
        ]),
        md.Element('tbody', [
          _tr(['------------', '--------']),
          _tr(['amid', 'dev']),
        ]),
      ]);
      final span = MarkdownPlusVisitor(MarkdownThemes.nord).visitElement(table);
      final text = _plainText(span!);
      expect(text.contains('amid'), isTrue);
      // 'Name' column stays 4 wide, not 12.
      expect(text.contains('│ Name │ Role │'), isTrue);
      expect(text, isNot(contains('------------')));
    });

    test('themes render consistently', () async {
      await testNocterm('themes render consistently', (tester) async {
        for (final theme in MarkdownThemes.gallery) {
          await tester.pumpComponent(
            _md('# Themed\n\nText and `code`', theme: theme),
          );
          expect(tester.terminalState, containsText('Themed'));
          expect(tester.terminalState, containsText('Text and'));
        }
      });
    });
  });

  group('state invalidation', () {
    // The cycler re-uses one component state and switches props via
    // setState — the real update path a growing chat reply goes through.
    test('re-renders when only builders change', () async {
      // Regression: ansi256/builders were missing from the re-parse
      // condition, so toggling just them kept painting stale spans.
      await testNocterm('re-renders when only builders change', (tester) async {
        await tester.pumpComponent(
          _PropCycler([
            _md('# Title'),
            _md(
              '# Title',
              builders: {
                'h1': (element, visitor) => const TextSpan(text: 'rebuilt'),
              },
            ),
          ]),
        );
        expect(tester.terminalState, containsText('# Title'));

        await tester.sendKey(LogicalKey.arrowRight);
        expect(tester.terminalState, containsText('rebuilt'));
        expect(tester.terminalState, isNot(containsText('# Title')));
      });
    });

    test('re-renders cached blocks when maxWidth changes', () async {
      // Regression: a maxWidth change re-parsed but did not clear the block
      // cache, so rules and tables kept their old width after a resize.
      await testNocterm('re-renders cached blocks when maxWidth changes', (
        tester,
      ) async {
        await tester.pumpComponent(
          _PropCycler([
            _md('above\n\n---\n\nbelow', maxWidth: 80),
            _md('above\n\n---\n\nbelow', maxWidth: 24),
          ]),
        );
        expect(tester.terminalState, containsText('─' * 40));

        await tester.sendKey(LogicalKey.arrowRight);
        expect(tester.terminalState, containsText('─' * 24));
        expect(tester.terminalState, isNot(containsText('─' * 40)));
      });
    });

    test('cache key distinguishes a heading from plain text', () async {
      // Regression: the memo cache keyed on textContent only, so a heading
      // sharing its text with an earlier paragraph rendered as that
      // paragraph (marker and heading style lost).
      await testNocterm('cache key distinguishes a heading from plain text', (
        tester,
      ) async {
        await tester.pumpComponent(_PropCycler([_md('hello'), _md('# hello')]));
        expect(tester.terminalState, containsText('hello'));

        await tester.sendKey(LogicalKey.arrowRight);
        expect(tester.terminalState, containsText('# hello'));
      });
    });
  });
}

md.Element _tr(List<String> cells) =>
    md.Element('tr', [for (final cell in cells) md.Element.text('th', cell)]);

String _plainText(InlineSpan span) {
  if (span is! TextSpan) return '';
  return (span.text ?? '') +
      (span.children ?? const <InlineSpan>[]).map(_plainText).join();
}

/// Host that keeps one component state alive and swaps the [MarkdownPlus]
/// props through `setState` on →, mimicking a parent rebuild.
class _PropCycler extends StatefulComponent {
  const _PropCycler(this.variants);

  final List<MarkdownPlus> variants;

  @override
  State<_PropCycler> createState() => _PropCyclerState();
}

class _PropCyclerState extends State<_PropCycler> {
  int _index = 0;

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowRight) {
          setState(() => _index = (_index + 1) % component.variants.length);
          return true;
        }
        return false;
      },
      child: component.variants[_index],
    );
  }
}
