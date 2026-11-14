import 'package:markdown/markdown.dart' as md;

/// Parses markdown into an AST, applying post-passes that the upstream
/// parser does not cover (currently: definition lists and front matter).
List<md.Node> parseDocument(String text, {md.ExtensionSet? extensionSet}) {
  final document = md.Document(
    extensionSet: extensionSet ?? md.ExtensionSet.gitHubWeb,
    encodeHtml: false,
  );
  final split = _splitFrontMatter(text);
  final nodes = split == null
      ? document.parse(text)
      : <md.Node>[split.$1, ...document.parse(split.$2)];
  return _withDefinitionLists(nodes);
}

/// Splits a leading YAML front matter block off the source text.
///
/// Front matter is `---` on the first line, an inner payload, and a closing
/// `---` line; it becomes a `front_matter` element carrying the raw inner
/// text. The renderer skips it by default, but a `'front_matter'` per-tag
/// builder can pick it up. A first line of `---` with no matching closer is
/// not front matter: it renders as a horizontal rule, like in any markdown
/// document.
(md.Element frontMatter, String rest)? _splitFrontMatter(String text) {
  final lines = text.split('\n');
  if (lines.first.trimRight() != '---') return null;
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trimRight() != '---') continue;
    final inner = lines.sublist(1, i).join('\n');
    final rest = lines.sublist(i + 1).join('\n');
    return (md.Element('front_matter', <md.Node>[md.Text(inner)]), rest);
  }
  return null;
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
