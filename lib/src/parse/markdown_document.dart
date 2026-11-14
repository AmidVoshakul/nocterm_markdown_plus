import 'package:markdown/markdown.dart' as md;

/// Parses markdown into an AST, applying post-passes that the upstream
/// parser does not cover (currently: definition lists).
List<md.Node> parseDocument(String text, {md.ExtensionSet? extensionSet}) {
  final document = md.Document(
    extensionSet: extensionSet ?? md.ExtensionSet.gitHubWeb,
    encodeHtml: false,
  );
  return _withDefinitionLists(document.parse(text));
}

/// Rewrites `term\n: description` paragraphs into definition lists.
///
/// The upstream package has no definition-list syntax, and consecutive lines
/// of `term` + `: description` parse as a single lazy paragraph, so the
/// paragraph is split at its first `': '` line: everything before becomes
/// the term, each `': '` line (with lazy continuations) a description.
/// Nested elements are rebuilt rather than mutated, because list elements
/// carry `List<Element>` children that reject mixed `List<Node>` updates.
List<md.Node> _withDefinitionLists(List<md.Node> nodes) {
  final result = <md.Node>[];
  for (final node in nodes) {
    if (node is md.Element && node.tag == 'p') {
      final list = _definitionListFrom(node);
      if (list != null) {
        result.add(list);
        continue;
      }
    }
    if (node is md.Element && node.children != null) {
      final rebuilt = _withDefinitionLists(node.children!);
      if (_sameNodes(node.children!, rebuilt)) {
        result.add(node);
      } else {
        result.add(
          md.Element(node.tag, rebuilt)..attributes.addAll(node.attributes),
        );
      }
    } else {
      result.add(node);
    }
  }
  return result;
}

/// Builds a `dl` element from a definition paragraph, or null when the
/// paragraph holds no `': '` description line.
md.Element? _definitionListFrom(md.Element paragraph) {
  final lines = paragraph.textContent.split('\n');
  final descriptionStart = lines.indexWhere((line) => line.startsWith(': '));
  if (descriptionStart < 0) return null;

  final term = lines.sublist(0, descriptionStart).join(' ').trim();
  final descriptions = <String>[];
  for (var i = descriptionStart; i < lines.length; i++) {
    final line = lines[i];
    if (line.startsWith(': ')) {
      descriptions.add(line.substring(2));
    } else if (descriptions.isNotEmpty) {
      descriptions[descriptions.length - 1] += ' $line';
    }
  }

  final list = md.Element('dl', <md.Node>[]);
  if (term.isNotEmpty) {
    list.children!.add(md.Element('dt', <md.Node>[md.Text(term)]));
  }
  for (final description in descriptions) {
    list.children!.add(md.Element('dd', <md.Node>[md.Text(description)]));
  }
  return list;
}

bool _sameNodes(List<md.Node> a, List<md.Node> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}
