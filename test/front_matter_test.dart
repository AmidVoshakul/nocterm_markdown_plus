import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('front matter parsing', () {
    test('splits YAML front matter into a front_matter element', () {
      final nodes = parseDocument('---\ntitle: Demo\n---\n\n# Hi');
      expect(nodes, hasLength(2));
      final fm = nodes.first as md.Element;
      expect(fm.tag, 'front_matter');
      expect(fm.textContent, 'title: Demo');
      final heading = nodes.last as md.Element;
      expect(heading.tag, 'h1');
    });

    test('a leading hr with no closer is not front matter', () {
      final nodes = parseDocument('---\n\n# Hi');
      final tags = nodes.whereType<md.Element>().map((e) => e.tag);
      expect(tags, isNot(contains('front_matter')));
    });

    test('front matter is separated from a mid-document hr', () {
      final nodes = parseDocument('---\na: 1\n---\n\n# Hi\n\n---\n\n# Bye');
      final fm = nodes.first as md.Element;
      expect(fm.tag, 'front_matter');
      final tags = nodes.whereType<md.Element>().map((e) => e.tag).toList();
      expect(tags, contains('hr'));
    });
  });

  group('front matter rendering', () {
    test('is skipped by default', () async {
      await testNocterm('is skipped by default', (tester) async {
        await tester.pumpComponent(
          MarkdownPlus('---\ntitle: Demo\n---\n\n# Hi'),
        );
        final text = tester.terminalState.getText();
        expect(text, isNot(contains('title: Demo')));
        expect(text, contains('Hi'));
      });
    });

    test('a leading hr with no closer still renders as an hr', () async {
      await testNocterm('a leading hr with no closer still renders as an hr', (
        tester,
      ) async {
        await tester.pumpComponent(MarkdownPlus('---\n\n# Hi'));
        final lines = tester.terminalState.getText().split('\n');
        expect(lines.any((l) => l.contains('─')), isTrue);
        expect(tester.terminalState.getText(), contains('Hi'));
      });
    });

    test('a mid-document hr survives a front matter block', () async {
      await testNocterm('a mid-document hr survives a front matter block', (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus('---\na: 1\n---\n\n# Hi\n\n---\n\n# Bye'),
        );
        final text = tester.terminalState.getText();
        expect(text, isNot(contains('a: 1')));
        expect(text, contains('Hi'));
        expect(text, contains('Bye'));
        final lines = text.split('\n');
        expect(lines.any((l) => l.contains('─')), isTrue);
      });
    });

    test("builders can render the 'front_matter' tag", () async {
      await testNocterm("builders can render the 'front_matter' tag", (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '---\ntitle: Demo\n---\n\n# Hi',
            builders: {
              'front_matter': (element, visitor) => TextSpan(
                children: [
                  TextSpan(
                    text: '[meta] ',
                    style: visitor.theme.linkStyle?.toTextStyle(),
                  ),
                  TextSpan(text: element.textContent),
                ],
              ),
            },
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('[meta] title: Demo'));
        expect(text, contains('Hi'));
      });
    });
  });
}
