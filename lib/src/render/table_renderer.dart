import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart';

import '../theme/markdown_theme.dart';
import '../util/unicode_width.dart';
import 'markdown_visitor.dart';

/// Column alignment parsed from a GFM delimiter row (`:--`, `--:`, `:-:`).
enum _Align { left, center, right }

class _Cell {
  const _Cell(this.spans, this.plain, this.align);

  final List<InlineSpan> spans;
  final String plain;
  final _Align align;
}

class _Row {
  const _Row(this.cells, this.isHeader);

  final List<_Cell> cells;
  final bool isHeader;
}

/// Renders GFM tables as a full-box grid.
///
/// Beyond the basics this renderer adds: separators between every row,
/// inline markdown styles inside cells, and column alignment from the
/// delimiter row. Cell content wraps by display width with per-run styles.
class TableRenderer {
  const TableRenderer._();

  static InlineSpan render(
    md.Element table,
    MarkdownTheme theme,
    MarkdownPlusVisitor visitor, {
    int? maxWidth,
    String indent = '',
  }) {
    final rows = <_Row>[];
    final naturalWidths = <int>[];
    var alignments = <_Align>[];
    var isHeaderRow = false;

    void collect(md.Element parent) {
      for (final child in parent.children ?? const <md.Node>[]) {
        if (child is! md.Element) continue;
        if (child.tag == 'thead' || child.tag == 'tbody') {
          isHeaderRow = child.tag == 'thead';
          collect(child);
        } else if (child.tag == 'tr') {
          final cells = <String>[];
          for (final cellChild in child.children ?? const <md.Node>[]) {
            if (cellChild is md.Element &&
                (cellChild.tag == 'th' || cellChild.tag == 'td')) {
              cells.add(cellChild.textContent.trim());
            }
          }
          // A delimiter row leaking into the body must never count as data
          // (it would inflate every column); its alignment spec is kept.
          final align = _alignmentOf(cells);
          if (align != null) {
            if (alignments.isEmpty) alignments = align;
            continue;
          }
          final cellSpans = <_Cell>[];
          for (final cellChild in child.children ?? const <md.Node>[]) {
            if (cellChild is md.Element &&
                (cellChild.tag == 'th' || cellChild.tag == 'td')) {
              cellSpans.add(
                _Cell(
                  childrenOf(visitor.visitChildren(cellChild)),
                  cellChild.textContent.trim(),
                  _Align.left,
                ),
              );
            }
          }
          rows.add(_Row(cellSpans, isHeaderRow));
          for (var i = 0; i < cellSpans.length; i++) {
            final width = UnicodeWidth.stringWidth(cellSpans[i].plain);
            if (i >= naturalWidths.length) naturalWidths.add(width);
            if (width > naturalWidths[i]) naturalWidths[i] = width;
          }
        }
      }
    }

    collect(table);
    if (rows.isEmpty || naturalWidths.isEmpty) return const TextSpan(text: '');

    final widths = _distribute(naturalWidths, maxWidth);
    final grid = <_Row>[
      for (final row in rows)
        _Row([
          for (var c = 0; c < row.cells.length; c++)
            _Cell(
              row.cells[c].spans,
              row.cells[c].plain,
              c < alignments.length ? alignments[c] : _Align.left,
            ),
        ], row.isHeader),
    ];

    final borderStyle = (theme.tableBorderStyle ?? theme.baseTextStyle)
        .toTextStyle();
    final headerStyle = (theme.tableHeaderStyle ?? theme.baseTextStyle)
        .toTextStyle();
    final cellStyle = (theme.tableCellStyle ?? theme.baseTextStyle)
        .toTextStyle();

    final spans = <InlineSpan>[if (indent.isNotEmpty) TextSpan(text: indent)];

    void border(String left, String middle, String right) {
      final line = StringBuffer(left);
      for (var i = 0; i < widths.length; i++) {
        line.write('─' * (widths[i] + 2));
        if (i < widths.length - 1) line.write(middle);
      }
      line.write(right);
      // The newline rides inside the styled span, matching how horizontal
      // rules are emitted — this keeps border lines robust across terminals.
      spans.add(TextSpan(text: '$line\n', style: borderStyle));
    }

    border('┌', '┬', '┐');
    for (var r = 0; r < grid.length; r++) {
      final row = grid[r];
      final style = row.isHeader ? headerStyle : cellStyle;
      final wrapped = <List<List<InlineSpan>>>[];
      var height = 1;
      for (var c = 0; c < widths.length; c++) {
        final cell = c < row.cells.length
            ? row.cells[c]
            : const _Cell(<InlineSpan>[], '', _Align.left);
        final lines = _wrapCell(cell.spans, widths[c], cell.align, style);
        wrapped.add(lines);
        height = math.max(height, lines.length);
      }
      for (var line = 0; line < height; line++) {
        final parts = <InlineSpan>[TextSpan(text: '│', style: borderStyle)];
        for (var c = 0; c < widths.length; c++) {
          parts.add(TextSpan(text: ' ', style: style));
          final cellLines = wrapped[c];
          if (line < cellLines.length) {
            parts.addAll(cellLines[line]);
          } else {
            parts.add(TextSpan(text: ' ' * widths[c], style: style));
          }
          final last = c == widths.length - 1;
          parts.add(TextSpan(text: last ? ' │\n' : ' │', style: borderStyle));
        }
        spans.add(TextSpan(children: parts));
      }
      border(
        r < rows.length - 1 ? '├┼┤'[0] : '└',
        r < rows.length - 1 ? '┼' : '┴',
        r < rows.length - 1 ? '┤' : '┘',
      );
    }
    spans.add(const TextSpan(text: '\n'));

    return TextSpan(children: spans);
  }

  /// Returns the alignment spec when [cells] is a delimiter row, else null.
  static List<_Align>? _alignmentOf(List<String> cells) {
    if (cells.isEmpty) return null;
    final aligns = <_Align>[];
    for (final cell in cells) {
      final t = cell.trim();
      if (!RegExp(r'^:?-+:?$').hasMatch(t)) return null;
      final left = t.startsWith(':');
      final right = t.endsWith(':');
      aligns.add(
        left && right
            ? _Align.center
            : right
            ? _Align.right
            : _Align.left,
      );
    }
    return aligns;
  }

  static List<int> _distribute(List<int> naturalWidths, int? maxWidth) {
    final overhead = 3 * naturalWidths.length + 1;
    final naturalTotal = naturalWidths.fold(0, (s, w) => s + w) + overhead;
    if (maxWidth == null || naturalTotal <= maxWidth) {
      return List.of(naturalWidths);
    }

    const minColWidth = 3;
    final available = maxWidth - overhead;
    // Degenerate case (very narrow terminal): keep the grid shape with
    // minimum columns and let the terminal soft-wrap the overflow rather
    // than corrupting column alignment.
    if (available < naturalWidths.length * minColWidth) {
      return List.filled(naturalWidths.length, minColWidth);
    }

    final totalNatural = naturalWidths.fold(0, (s, w) => s + w);
    final result = List<int>.filled(naturalWidths.length, 0);
    var allocated = 0;
    for (var i = 0; i < naturalWidths.length; i++) {
      result[i] = math.max(
        minColWidth,
        (naturalWidths[i] * available / totalNatural).floor(),
      );
      allocated += result[i];
    }
    var remaining = available - allocated;
    while (remaining > 0) {
      var best = 0;
      var deficit = 0;
      for (var i = 0; i < naturalWidths.length; i++) {
        final d = naturalWidths[i] - result[i];
        if (d > deficit) {
          deficit = d;
          best = i;
        }
      }
      if (deficit == 0) break;
      result[best]++;
      remaining--;
    }
    while (remaining < 0) {
      var best = 0;
      var excess = 0;
      for (var i = 0; i < naturalWidths.length; i++) {
        final e = result[i] - minColWidth;
        if (e > excess) {
          excess = e;
          best = i;
        }
      }
      if (excess == 0) break;
      result[best]--;
      remaining++;
    }
    return result;
  }

  /// Flattens a span tree into text runs, propagating the nearest style down
  /// to unstyled leaves.
  static List<_Run> _runsOf(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return const [];
    final style = span.style ?? inherited;
    final self = span.text == null || span.text!.isEmpty
        ? const <_Run>[]
        : [_Run(span.text!, style)];
    return [
      ...self,
      for (final child in span.children ?? const <InlineSpan>[])
        ..._runsOf(child, style),
    ];
  }

  /// Wraps styled cell content to [width] display columns, padding every
  /// visual line to exactly [width] according to [align].
  static List<List<InlineSpan>> _wrapCell(
    List<InlineSpan> spans,
    int width,
    _Align align,
    TextStyle base,
  ) {
    final runs = <_Run>[];
    for (final span in spans) {
      runs.addAll(_runsOf(span, base));
    }

    final lines = <List<InlineSpan>>[];
    var current = <InlineSpan>[];
    var currentWidth = 0;

    void flush() {
      final pad = width - currentWidth;
      final left = switch (align) {
        _Align.left => 0,
        _Align.right => pad,
        _Align.center => pad ~/ 2,
      };
      final right = pad - left;
      final line = <InlineSpan>[
        if (left > 0) TextSpan(text: ' ' * left, style: base),
        ...current,
        if (right > 0) TextSpan(text: ' ' * right, style: base),
      ];
      lines.add(line);
      current = <InlineSpan>[];
      currentWidth = 0;
    }

    void addWord(String word, TextStyle? style) {
      final wordWidth = UnicodeWidth.stringWidth(word);
      if (currentWidth > 0 && currentWidth + 1 + wordWidth > width) {
        flush();
      }
      if (currentWidth == 0 && wordWidth > width) {
        final parts = _breakWord(word, width, style);
        for (var i = 0; i < parts.length; i++) {
          if (currentWidth > 0) flush();
          final part = parts[i];
          current.add(part);
          currentWidth += UnicodeWidth.stringWidth(
            part is TextSpan ? part.text ?? '' : '',
          );
          if (i < parts.length - 1) flush();
        }
        return;
      }
      if (currentWidth > 0) {
        current.add(TextSpan(text: ' ', style: base));
        currentWidth += 1;
      }
      current.add(TextSpan(text: word, style: style));
      currentWidth += wordWidth;
    }

    for (final run in runs) {
      final segments = run.text.split('\n');
      for (var si = 0; si < segments.length; si++) {
        if (si > 0 && (current.isNotEmpty || currentWidth > 0)) flush();
        for (final word in segments[si].split(' ')) {
          if (word.isEmpty) continue;
          addWord(word, run.style);
        }
      }
    }
    flush();
    return lines;
  }

  /// Splits an overlong word into fragments of at most [width] columns,
  /// keeping the word's style on every fragment.
  static List<InlineSpan> _breakWord(String word, int width, TextStyle? style) {
    final parts = <InlineSpan>[];
    var text = '';
    var textWidth = 0;
    for (final grapheme in word.characters) {
      final w = UnicodeWidth.graphemeWidth(grapheme);
      if (textWidth + w > width && text.isNotEmpty) {
        parts.add(TextSpan(text: text, style: style));
        text = grapheme;
        textWidth = w;
      } else {
        text += grapheme;
        textWidth += w;
      }
    }
    if (text.isNotEmpty) parts.add(TextSpan(text: text, style: style));
    return parts.isEmpty ? [const TextSpan(text: '')] : parts;
  }
}

class _Run {
  const _Run(this.text, this.style);

  final String text;
  final TextStyle? style;
}
