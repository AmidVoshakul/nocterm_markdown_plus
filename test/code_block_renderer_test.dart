import 'package:nocterm_markdown_plus/src/render/code_block_renderer.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

class _ThrowingHighlighter extends CodeHighlighter {
  const _ThrowingHighlighter();
  @override
  List<List<CodeToken>> highlight(String code, {String? language}) {
    throw StateError('boom');
  }
}

void main() {
  group('CodeBlockRenderer', () {
    test('renders without a highlighter', () {
      final span = CodeBlockRenderer.render(
        code: 'a\nb',
        language: null,
        theme: MarkdownThemes.catppuccinMocha,
        highlighter: null,
        lineNumbers: true,
      );
      expect(span, isNotNull);
    });

    test('falls back when highlighter throws', () {
      final span = CodeBlockRenderer.render(
        code: 'a\nb',
        language: 'dart',
        theme: MarkdownThemes.catppuccinMocha,
        highlighter: const _ThrowingHighlighter(),
      );
      expect(span, isNotNull);
    });
  });
}
