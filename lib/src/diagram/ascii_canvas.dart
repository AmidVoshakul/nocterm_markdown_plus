/// A character grid for rendering terminal diagrams.
///
/// Self-contained on purpose: no TUI-framework types, so any host can turn
/// the grid into its own styled text. Box-drawing primitives are implemented
/// here instead of imported from a framework.
library;

import 'package:characters/characters.dart';

/// Cell style roles used for theming.
enum DiagramCellStyle { node, edge, label, plain }

class _Cell {
  _Cell(this.char, this.style);

  String char;
  DiagramCellStyle style;
}

/// A drawable grid of characters with per-cell style roles.
class AsciiCanvas {
  AsciiCanvas(this.width, this.height)
    : _cells = List.generate(
        height,
        (_) => List.generate(width, (_) => _Cell(' ', DiagramCellStyle.plain)),
      );

  final int width;
  final int height;
  final List<List<_Cell>> _cells;

  /// Cells occupied by node boxes (border + interior). Edge segments skip
  /// these so an edge can never overwrite a box; arrowheads are still drawn
  /// on top (they mark the connection point on the box border).
  final Set<(int, int)> _protected = <(int, int)>{};

  void put(int x, int y, String char, DiagramCellStyle style) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    _cells[y][x] = _Cell(char, style);
  }

  void putText(int x, int y, String text, DiagramCellStyle style) {
    var column = x;
    for (final grapheme in text.characters) {
      put(column, y, grapheme, style);
      column += 1;
    }
  }

  /// Draws a box border. Corners vary by flavor: square, rounded, rhombus.
  void drawBox(
    int x,
    int y,
    int w,
    int h,
    DiagramCellStyle style, {
    BoxFlavor flavor = BoxFlavor.square,
  }) {
    if (w < 2 || h < 2) return;
    final corners = switch (flavor) {
      BoxFlavor.square => ('┌', '┐', '└', '┘'),
      BoxFlavor.rounded => ('╭', '╮', '╰', '╯'),
      BoxFlavor.rhombus => ('╱', '╲', '╲', '╱'),
    };
    put(x, y, corners.$1, style);
    put(x + w - 1, y, corners.$2, style);
    put(x, y + h - 1, corners.$3, style);
    put(x + w - 1, y + h - 1, corners.$4, style);
    for (var column = x + 1; column < x + w - 1; column++) {
      put(column, y, '─', style);
      put(column, y + h - 1, '─', style);
    }
    for (var row = y + 1; row < y + h - 1; row++) {
      put(x, row, '│', style);
      put(x + w - 1, row, '│', style);
    }
    for (var yy = y; yy < y + h; yy++) {
      for (var xx = x; xx < x + w; xx++) {
        _protected.add((xx, yy));
      }
    }
  }

  /// Draws one straight segment, choosing the matching box-drawing glyph.
  void drawSegment(int x1, int y1, int x2, int y2, DiagramCellStyle style) {
    if (y1 == y2) {
      final from = x1 < x2 ? x1 : x2;
      final to = x1 < x2 ? x2 : x1;
      for (var x = from; x <= to; x++) {
        if (_protected.contains((x, y1))) continue;
        put(x, y1, _mergeLine(_cells[y1][x].char, '─'), style);
      }
      return;
    }
    if (x1 == x2) {
      final from = y1 < y2 ? y1 : y2;
      final to = y1 < y2 ? y2 : y1;
      for (var y = from; y <= to; y++) {
        if (_protected.contains((x1, y))) continue;
        put(x1, y, _mergeLine(_cells[y][x1].char, '│'), style);
      }
      return;
    }
    // Diagonal (Bresenham); diagonals cross, so they never merge.
    var x = x1;
    var y = y1;
    final dx = (x2 - x1).abs();
    final dy = (y2 - y1).abs();
    final sx = x1 < x2 ? 1 : -1;
    final sy = y1 < y2 ? 1 : -1;
    var err = dx - dy;
    while (true) {
      if (!_protected.contains((x, y))) {
        final grapheme = dx >= dy ? '╱' : '╲';
        final flipped = (sx > 0) != (sy > 0);
        put(x, y, flipped ? (grapheme == '╱' ? '╲' : '╱') : grapheme, style);
      }
      if (x == x2 && y == y2) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x += sx;
      }
      if (e2 < dx) {
        err += dx;
        y += sy;
      }
    }
  }

  /// Draws an arrowhead glyph pointing in the given direction.
  void drawArrow(
    int x,
    int y,
    DiagramDirection direction,
    DiagramCellStyle style,
  ) {
    final char = switch (direction) {
      DiagramDirection.right => '►',
      DiagramDirection.left => '◄',
      DiagramDirection.down => '▼',
      DiagramDirection.up => '▲',
    };
    put(x, y, char, style);
  }

  String charAt(int x, int y) =>
      (x < 0 || y < 0 || x >= width || y >= height) ? ' ' : _cells[y][x].char;

  DiagramCellStyle styleAt(int x, int y) =>
      (x < 0 || y < 0 || x >= width || y >= height)
      ? DiagramCellStyle.plain
      : _cells[y][x].style;

  List<String> toLines() => [
    for (var y = 0; y < height; y++) _cells[y].map((c) => c.char).join(),
  ];

  /// Each row as contiguous styled segments, ready for terminal output.
  List<List<DiagramRun>> toStyledLines() {
    final lines = <List<DiagramRun>>[];
    for (var y = 0; y < height; y++) {
      final segments = <DiagramRun>[];
      var current = '';
      var currentStyle = _cells[y].first.style;
      for (final cell in _cells[y]) {
        if (cell.style == currentStyle) {
          current += cell.char;
        } else {
          segments.add(DiagramRun(current, currentStyle));
          current = cell.char;
          currentStyle = cell.style;
        }
      }
      segments.add(DiagramRun(current, currentStyle));
      lines.add(segments);
    }
    return lines;
  }
}

/// Box corner flavors for [AsciiCanvas.drawBox].
enum BoxFlavor { square, rounded, rhombus }

class DiagramRun {
  DiagramRun(this.text, this.style);

  final String text;
  final DiagramCellStyle style;
}

enum DiagramDirection { right, left, up, down }

/// Picks the glyph where a new segment crosses an existing line.
String _mergeLine(String existing, String incoming) {
  if (existing == ' ' || existing == incoming) return incoming;
  const lines = {
    '─',
    '│',
    '╱',
    '╲',
    '┌',
    '┐',
    '└',
    '┘',
    '├',
    '┤',
    '┬',
    '┴',
    '┼',
  };
  if (!lines.contains(existing)) return incoming;
  final both = existing + incoming;
  const crossings = {
    '─│': '┼',
    '│─': '┼',
    '─┌': '┬',
    '┌─': '┬',
    '─┐': '┬',
    '┐─': '┬',
    '─└': '┴',
    '└─': '┴',
    '─┘': '┴',
    '┘─': '┴',
    '│┌': '├',
    '┌│': '├',
    '│┐': '┤',
    '┐│': '┤',
    '│└': '├',
    '└│': '├',
    '│┘': '┤',
    '┘│': '┤',
    '┌┐': '─',
    '└┘': '─',
  };
  return crossings[both] ?? incoming;
}
