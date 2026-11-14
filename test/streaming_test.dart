import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

String _flat(InlineSpan s) => s is TextSpan
    ? (s.text ?? '') + (s.children ?? const <InlineSpan>[]).map(_flat).join()
    : '';

List<InlineSpan> _parse(String text, Map<String, List<InlineSpan>> cache) {
  final doc = md.Document(
    extensionSet: md.ExtensionSet.gitHubWeb,
    encodeHtml: false,
  );
  return MarkdownPlusVisitor(
    MarkdownThemes.nord,
    blockCache: cache,
  ).visitNodes(doc.parse(text));
}

void main() {
  group('streaming memo-cache', () {
    test('settled blocks are reused across renders', () {
      final cache = <String, List<InlineSpan>>{};
      final first = _parse('# Title\n\nfirst paragraph', cache);
      final second = _parse('# Title\n\nfirst paragraph changed', cache);
      // The title block is identical text -> identical span instances.
      expect(identical(first.first, second.first), isTrue);
      // The changed paragraph is re-rendered.
      final secondText = second.map((s) => _flat(s)).join();
      expect(secondText.contains('changed'), isTrue);
    });

    test('full render equals incremental render', () {
      final chunks = [
        '# Stream',
        '# Stream\n\nGrowing',
        '# Stream\n\nGrowing response',
        '# Stream\n\nGrowing response with `code`.',
      ];
      final cache = <String, List<InlineSpan>>{};
      String incremental = '';
      for (final chunk in chunks) {
        incremental = _flat(TextSpan(children: _parse(chunk, cache)));
      }
      final fullCache = <String, List<InlineSpan>>{};
      final full = _flat(TextSpan(children: _parse(chunks.last, fullCache)));
      expect(incremental, full);
    });

    test('widget reuses blocks while streaming', () async {
      await testNocterm('widget reuses blocks while streaming', (tester) async {
        await tester.pumpComponent(
          MarkdownPlus('# Live\n\ntoken one', theme: MarkdownThemes.nord),
        );
        expect(tester.terminalState, containsText('Live'));
        await tester.pumpComponent(
          MarkdownPlus('# Live\n\ntoken one two', theme: MarkdownThemes.nord),
        );
        final state = tester.terminalState.getText();
        expect(state.contains('Live'), isTrue);
        expect(state.contains('token one two'), isTrue);
      });
    });
  });
}
