import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('per-tag builders', () {
    test('custom builder replaces the default tag render', () async {
      await testNocterm('custom builder replaces the default tag render', (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '| a | b |\n|---|---|\n| 1 | 2 |',
            theme: MarkdownThemes.nord,
            builders: {
              'table': (element, visitor) =>
                  const TextSpan(text: 'CUSTOM-TABLE'),
            },
          ),
        );
        expect(tester.terminalState, containsText('CUSTOM-TABLE'));
        expect(tester.terminalState, isNot(containsText('\u250c')));
      });
    });

    test('builder receives the parsed element', () {
      md.Element? seen;
      final doc = md.Document(extensionSet: md.ExtensionSet.gitHubWeb);
      final visitor = MarkdownPlusVisitor(
        MarkdownThemes.nord,
        builders: {
          'a': (element, visitor) {
            seen = element;
            return null;
          },
        },
      );
      visitor.visitNodes(doc.parse('[nocterm](https://nocterm.dev)'));
      expect(seen?.tag, 'a');
      expect(seen?.attributes['href'], 'https://nocterm.dev');
    });

    test('returning null falls back to the default render', () async {
      await testNocterm('returning null falls back to the default render', (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '# Heading',
            theme: MarkdownThemes.nord,
            builders: {'h1': (element, visitor) => null},
          ),
        );
        expect(tester.terminalState, containsText('Heading'));
      });
    });
  });
}
