import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

class _Styled {
  _Styled(this.text, this.style);

  final String text;
  final TextStyle? style;
}

List<_Styled> _styledText(InlineSpan span) {
  if (span is! TextSpan) return const [];
  final self = span.text == null
      ? const <_Styled>[]
      : [_Styled(span.text!, span.style)];
  return [
    ...self,
    for (final child in span.children ?? const <InlineSpan>[])
      ..._styledText(child),
  ];
}

MarkdownTheme get _theme => MarkdownThemes.catppuccinMocha;

class _ThrowingHighlighter extends CodeHighlighter {
  const _ThrowingHighlighter();

  @override
  List<List<CodeToken>> highlight(String code, {String? language}) {
    throw StateError('boom');
  }
}

class _EmptyTokenHighlighter extends CodeHighlighter {
  const _EmptyTokenHighlighter();

  @override
  List<List<CodeToken>> highlight(String code, {String? language}) {
    return code.split('\n').map((_) => const <CodeToken>[]).toList();
  }
}

List<_Styled> _render(String markdown, {CodeHighlighter? highlighter}) {
  final doc = md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final spans = MarkdownPlusVisitor(
    _theme,
    highlighter: highlighter,
  ).visitNodes(doc.parse(markdown));
  return spans.expand(_styledText).toList();
}

void main() {
  group('diff rendering', () {
    test('added lines use the added slot', () {
      final text = _render('```diff\n+ final greeting = "hi";\n```');
      final line = text.firstWhere((s) => s.text.contains('greeting'));
      expect(line.style?.color, _theme.diffAddedStyle?.color);
    });

    test('removed lines use the removed slot', () {
      final text = _render('```diff\n- final greeting = "hi";\n```');
      final line = text.firstWhere((s) => s.text.contains('greeting'));
      expect(line.style?.color, _theme.diffRemovedStyle?.color);
    });

    test('hunk headers use the hunk slot', () {
      final text = _render('```diff\n@@ -1,2 +1,2 @@\n context\n```');
      final hunk = text.firstWhere((s) => s.text.contains('@@'));
      expect(hunk.style?.color, _theme.diffHunkStyle?.color);
    });

    test('git metadata lines use the meta slot', () {
      final text = _render('''```diff
diff --git a/README.md b/README.md
index 1234567..89abcde 100644
--- a/README.md
+++ b/README.md
@@ -1 +1 @@
-old
+new
```''');
      final meta = text.firstWhere((s) => s.text.contains('diff --git'));
      expect(meta.style?.color, _theme.diffMetaStyle?.color);
      final header = text.firstWhere((s) => s.text.contains('--- a/README.md'));
      expect(header.style?.color, _theme.diffMetaStyle?.color);
    });

    test('detects language from diff --git without plus-plus line', () {
      final text = _render(
        '```diff\ndiff --git a/main.dart b/main.dart\n@@ -1 +1 @@\n-old\n+new\n```',
      );
      expect(text.any((s) => s.text.contains('new')), isTrue);
    });

    test('falls back to plain tokens when highlighter throws', () {
      final text = _render(
        '```diff\n+ final x = 1;\n```',
        highlighter: const _ThrowingHighlighter(),
      );
      expect(text.any((s) => s.text.contains('final x')), isTrue);
    });

    test('renders content when highlighter returns no tokens', () {
      final text = _render(
        '```diff\n+ final x = 1;\n```',
        highlighter: const _EmptyTokenHighlighter(),
      );
      expect(text.any((s) => s.text.contains('final x')), isTrue);
    });

    test('context lines render plain', () {
      final text = _render('```diff\n@@ -1 +1 @@\n unchanged line\n```');
      final context = text.firstWhere((s) => s.text.contains('unchanged'));
      expect(context.style?.color, _theme.codeBlockStyle?.color);
    });

    test('patch blocks use the diff renderer', () {
      final text = _render('```patch\n+ added in patch\n```');
      final line = text.firstWhere((s) => s.text.contains('added in patch'));
      expect(line.style?.color, _theme.diffAddedStyle?.color);
    });

    test('diff with syntax highlighting (dart)', () {
      final text = _render(
        '```diff\n--- a/lib/main.dart\n+++ b/lib/main.dart\n@@ -1,3 +1,3 @@\n void main() {\n-  runApp(const OldApp());\n+  runApp(const NewApp());\n }\n```',
        highlighter: const SyntaxCoreHighlighter(),
      );
      final line = text.firstWhere((s) => s.text.contains('NewApp'));
      expect(line.style?.backgroundColor, isNotNull);
    });

    test('diff with syntax highlighting (python)', () {
      final text = _render(
        '```diff\n--- a/x.py\n+++ b/x.py\n@@ -1 +1 @@\n-def foo():\n+def bar():\n```',
        highlighter: const SyntaxCoreHighlighter(),
      );
      final line = text.firstWhere((s) => s.text.contains('bar'));
      expect(line.style?.backgroundColor, isNotNull);
    });

    test('diff with PlainHighlighter fallback', () {
      final text = _render(
        '```diff\n--- a/x.dart\n+++ b/x.dart\n@@ -1 +1 @@\n-old\n+new\n```',
        highlighter: const PlainHighlighter(),
      );
      final line = text.firstWhere((s) => s.text.contains('new'));
      expect(line.style?.backgroundColor, isNotNull);
    });

    test('diff language detection returns null for unknown extension', () {
      final text = _render(
        '```diff\n--- a/x.unknownext\n+++ b/x.unknownext\n@@ -1 +1 @@\n-old\n+new\n```',
        highlighter: const SyntaxCoreHighlighter(),
      );
      final line = text.firstWhere((s) => s.text.contains('new'));
      expect(line.style?.backgroundColor, isNotNull);
    });

    test('diff with /dev/null (deleted file) falls back to no language', () {
      final text = _render(
        '```diff\n--- a/x.dart\n+++ /dev/null\n@@ -1 +0,0 @@\n-deleted\n```',
        highlighter: const SyntaxCoreHighlighter(),
      );
      final line = text.firstWhere((s) => s.text.contains('deleted'));
      expect(line.style?.backgroundColor, isNotNull);
    });

    test('non-diff code blocks still render as code', () {
      final text = _render('```dart\nvoid main() {}\n```');
      final line = text.firstWhere((s) => s.text.contains('void main'));
      expect(line.style?.color, _theme.codeBlockStyle?.color);
    });
  });
}
