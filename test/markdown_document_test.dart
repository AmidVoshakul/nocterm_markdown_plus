import 'package:markdown/markdown.dart' as md;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('parseDocument', () {
    test('splits front matter', () {
      final nodes = parseDocument('---\ntitle: Demo\n---\n# Hi');
      expect((nodes.first as md.Element).tag, 'front_matter');
      expect(nodes.any((n) => n is md.Element && n.tag == 'h1'), isTrue);
    });

    test('keeps lone --- as horizontal rule', () {
      final nodes = parseDocument('---\n# Hi');
      expect((nodes.first as md.Element).tag, 'hr');
    });

    test('builds definition list with lazy continuation', () {
      final nodes = parseDocument('term\n: first\n  second');
      final dl = nodes.first as md.Element;
      expect(dl.tag, 'dl');
      expect(dl.children!.last is md.Element, isTrue);
      expect((dl.children!.last as md.Element).textContent, contains('second'));
    });

    test('rebuilds containers holding definition lists', () {
      final nodes = parseDocument('> term\n> : desc');
      final bq = nodes.first as md.Element;
      expect(bq.tag, 'blockquote');
      expect(
        bq.children!.first is md.Element &&
            (bq.children!.first as md.Element).tag == 'dl',
        isTrue,
      );
    });

    test('leaves paragraphs without description lines unchanged', () {
      final nodes = parseDocument('just a paragraph');
      expect((nodes.first as md.Element).tag, 'p');
    });

    test('handles empty input', () {
      final nodes = parseDocument('');
      expect(nodes, isEmpty);
    });
  });
}
