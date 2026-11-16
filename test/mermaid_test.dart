import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

String _flat(InlineSpan span) => span is TextSpan
    ? (span.text ?? '') +
          (span.children ?? const <InlineSpan>[]).map(_flat).join()
    : '';

List<String> _lines(List<InlineSpan> spans) =>
    spans.map(_flat).join().split('\n');

void main() {
  group('mermaid diagrams', () {
    test('flowchart renders boxes, edges and labels', () {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
graph TD
  A[Start] --> B[End]
  B -->|done| A
```'''),
          );
      final text = spans.map(_flat).join();
      expect(text.contains('Start'), isTrue);
      expect(text.contains('End'), isTrue);
      expect(text.contains('done'), isTrue);
      expect(text.contains('┌'), isTrue);
    });

    test('sequence diagram renders actors, labels and arrows', () {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
sequenceDiagram
    participant U as Пользователь
    participant D as Dart Package
    U->>D: parse(md)
    D-->>U: ready
```'''),
          );
      final text = spans.map(_flat).join();
      expect(text.contains('Пользователь'), isTrue);
      expect(text.contains('Dart Package'), isTrue);
      expect(text.contains('parse(md)'), isTrue);
      expect(text.contains('ready'), isTrue);
      expect(text.contains('►'), isTrue);
    });

    test('actor stick figure box aligns with participant boxes', () {
      // Regression: a sequence `actor` node is a stick figure (torso path +
      // head circle), not a box. Rasterizing from the first shape's bounds
      // alone dropped the actor's name box below the participants' row, so
      // its bottom border collided with the lifelines.
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
sequenceDiagram
    autonumber
    actor User as Пользователь
    participant Pkg as Dart Package
    User->>Pkg: render(markdownContent)
```'''),
          );
      final lines = _lines(spans);
      int? actorTop;
      int? participantTop;
      for (var i = 0; i < lines.length; i++) {
        actorTop ??= lines[i].contains('Пользователь') ? i : null;
        participantTop ??= lines[i].contains('Dart Package') ? i : null;
      }
      expect(actorTop, isNotNull);
      expect(participantTop, isNotNull);
      expect(actorTop, participantTop, reason: lines.join('\n'));
    });

    test('lifelines touch the participant boxes when shrunk', () {
      // Regression: node boxes hug their label (2 rows of padding), so a
      // shrunken diagram rounded the lifeline start — which sits inside the
      // participant's rect in scene px — to a row below the box, leaving
      // every box floating above its lifeline. Lifelines now anchor to the
      // box bottom.
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans =
          MarkdownPlusVisitor(
            MarkdownThemes.catppuccinMocha,
            maxWidth: 120,
          ).visitNodes(
            doc.parse('''```mermaid
sequenceDiagram
    actor User as Пользователь
    participant Pkg as Dart Package
    User->>Pkg: render(markdownContent)
```'''),
          );
      final lines = _lines(spans);
      final bottomRow = lines.indexWhere((l) => l.contains('└'));
      expect(bottomRow, greaterThan(0), reason: lines.join('\n'));
      expect(
        lines[bottomRow + 1].contains('│'),
        isTrue,
        reason: lines.join('\n'),
      );
    });

    test('autonumber prefixes the message label with a gap', () {
      // Regression: the message label and its autonumber are separate scene
      // texts; centering each independently glued them ("2запрашивает").
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
sequenceDiagram
    autonumber
    participant P as Пользователь
    participant D as Dart Package
    participant M as Markdown Parser
    participant E as Mermaid Engine
    P->>D: посылает markdown
    D->>M: запрашивает разбор
    M->>E: строит диаграмму
    E-->>M: ASCII сцена
    M-->>D: готовая сцена
    D-->>P: рисует в терминал
```'''),
          );
      final lines = _lines(spans).map((l) => l.trimRight());
      final glued = lines.where((l) => RegExp(r'\d[А-Яа-я]').hasMatch(l));
      expect(glued, isEmpty, reason: 'autonumber glued to its label: $glued');
      expect(
        lines.any((l) => RegExp(r'2\s+запрашивает разбор').hasMatch(l)),
        isTrue,
        reason: lines.join('\n'),
      );
    });

    test('four participants fit inside the canvas width', () {
      // Regression: label-hugging boxes shifted to the IR rect's left edge
      // pushed the last actor box past the canvas edge.
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
sequenceDiagram
    participant A as Пользователь
    participant B as Dart Package
    participant C as Markdown Parser
    participant D as Mermaid Engine
    A->>B: one
    B->>C: two
    C->>D: three
```'''),
          );
      final lines = _lines(spans);
      for (final line
          in lines
              .where((l) => l.contains('Mermaid Engine'))
              .map((l) => l.trimRight())) {
        expect(line.endsWith('Mermaid Engine │'), isTrue, reason: line);
      }
      for (final line
          in lines.where((l) => l.contains('┌')).map((l) => l.trimRight())) {
        expect(line.contains('┐'), isTrue, reason: line);
      }
    });

    test('flowchart with branching keeps box borders intact', () {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans =
          MarkdownPlusVisitor(
            MarkdownThemes.catppuccinMocha,
            maxWidth: 120,
          ).visitNodes(
            doc.parse('''```mermaid
flowchart LR
    A[Markdown] --> B[Parser]
    A --> C[Visitor]
    C --> D[Theme]
    C --> E[Terminal]
```'''),
          );
      final text = spans.map(_flat).join();
      for (final label in [
        'Markdown',
        'Parser',
        'Visitor',
        'Theme',
        'Terminal',
      ]) {
        expect(text, contains(label), reason: label);
      }
      expect(text, isNot(contains('\u2572\u2500\u2510')));
    });

    test('pie chart renders as aligned bar legend', () {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(
            doc.parse('''```mermaid
pie title Pets
    "Dogs" : 386
    "Cats" : 85
    "Rats" : 15
```'''),
          );
      final text = spans.map(_flat).join();
      expect(text, contains('Dogs'));
      expect(text, contains('Cats'));
      expect(text, contains('Rats'));
      expect(text, contains('100.0%'));
      expect(text, contains('\u2588'));
    });

    test('invalid mermaid source falls back to a code block', () {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubWeb,
        encodeHtml: false,
      );
      final spans = MarkdownPlusVisitor(MarkdownThemes.catppuccinMocha)
          .visitNodes(doc.parse('```mermaid\nnot a diagram at all\n```'));
      final text = spans.map(_flat).join();
      expect(text.contains('not a diagram at all'), isTrue);
    });
  });
}
