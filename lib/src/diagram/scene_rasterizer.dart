import 'dart:math' as math;

import 'package:mermaid_core/mermaid_core.dart';

import 'ascii_canvas.dart';

/// Rasterizes a mermaid-core `RenderScene` onto an [AsciiCanvas].
///
/// Scene units are SVG pixels; cells are drawn with a 1:2 width/height aspect
/// (one character is twice as tall as it is wide), so the scene is scaled to
/// roughly `cellWidth` units per character.
class SceneRasterizer {
  const SceneRasterizer._();

  static AsciiCanvas rasterize(RenderScene scene, {int? maxWidth}) {
    final maxCols = maxWidth ?? 80;
    // Terminal cells are roughly 8x16 scene px. Map the scene at that base
    // scale so diagrams keep their natural proportions, and only shrink
    // proportionally when the diagram would overflow maxCols. Stretching to
    // fill maxCols instead would blow actor boxes up to 26+ columns each.
    var cellW = 8.0;
    var cellH = 16.0;
    final naturalCols = scene.size.width / cellW;
    if (naturalCols > maxCols) {
      final scale = naturalCols / maxCols;
      cellW *= scale;
      cellH *= scale;
    }
    final canvas = AsciiCanvas(
      (scene.size.width / cellW).ceil() + 1,
      (scene.size.height / cellH).ceil() + 1,
    );

    int gx(double x) => (x / cellW).round();
    int gy(double y) => (y / cellH).round();

    // Bottom row of every drawn node box, per canvas column. Downward
    // verticals (lifelines) anchor to it below.
    final boxBottomByCol = List<int?>.filled(canvas.width, null);

    final nodeGroups = <SceneGroup>[];
    final clusterGroups = <SceneGroup>[];
    final edgeGroups = <SceneGroup>[];
    final looseShapes = <SceneShape>[];
    final looseTexts = <SceneText>[];

    void collect(SceneNode node) {
      if (node is SceneGroup) {
        switch (node.role) {
          case SceneGroupRole.node:
            nodeGroups.add(node);
          case SceneGroupRole.cluster:
            clusterGroups.add(node);
          case SceneGroupRole.edge:
          case SceneGroupRole.edgeLabel:
            edgeGroups.add(node);
          case SceneGroupRole.annotation:
          case SceneGroupRole.internal:
            for (final child in node.children) {
              collect(child);
            }
        }
      } else if (node is SceneShape) {
        looseShapes.add(node);
      } else if (node is SceneText) {
        looseTexts.add(node);
      }
    }

    for (final node in scene.nodes) {
      collect(node);
    }

    // 1. Cluster borders sit beneath everything they contain.
    for (final cluster in clusterGroups) {
      final body = _firstShape(cluster);
      if (body == null) continue;
      final bounds = _boundsOf(body.geometry);
      canvas.drawBox(
        gx(bounds.left),
        gy(bounds.top),
        math.max(3, (bounds.width / cellW).round()),
        math.max(3, (bounds.height / cellH).round()),
        DiagramCellStyle.node,
      );
    }

    // 2. Node boxes with their labels (sequence participants repeat at the
    // bottom; the first occurrence wins).
    final seenNodes = <String>{};
    for (final group in nodeGroups) {
      final body = _firstShape(group);
      if (body == null) continue;
      final bounds = _groupBounds(group, body);
      final label =
          group.children.whereType<SceneText>().firstOrNull?.text ?? '';
      final key = '$label@${gx(bounds.left)}';
      if (label.isNotEmpty && !seenNodes.add(key)) continue;
      final y = gy(bounds.top);
      final w = math.max(label.length + 4, (bounds.width / cellW).round());
      // Boxes hug their label, which can exceed the IR rect; anchor on the
      // rect's center (clamped to the canvas) instead of its left edge so the
      // box stays centered over its participant.
      final centerX = gx(bounds.left + bounds.width / 2);
      final x = math.max(0, math.min(centerX - w ~/ 2, canvas.width - w));
      final labelLines = _wrapText(label, w - 2);
      // Clamp slack: a node box hugs its label (2 rows of padding) instead of
      // stretching to the scene's routing gap.
      final h = math.max(
        3,
        math.min((bounds.height / cellH).round(), labelLines.length + 2),
      );
      canvas.drawBox(
        x,
        y,
        w,
        h,
        DiagramCellStyle.node,
        flavor: _flavor(body.geometry, bounds),
      );
      for (var column = x; column < x + w && column < canvas.width; column++) {
        boxBottomByCol[column] = math.max(
          boxBottomByCol[column] ?? -1,
          y + h - 1,
        );
      }
      if (label.isNotEmpty) {
        final top = y + math.max(0, (h - labelLines.length) ~/ 2).toInt();
        for (var i = 0; i < labelLines.length; i++) {
          final line = labelLines[i];
          canvas.putText(
            x + math.max(1, (w - line.length) ~/ 2),
            top + i,
            line,
            DiagramCellStyle.node,
          );
        }
      }
    }

    // A shrunk diagram rounds the lifeline start — which sits inside the
    // participant's rect in scene px — to a row below the label-clamped box,
    // leaving every box floating above its lifeline. Anchor downward
    // verticals to the box bottom instead.
    int liftVerticalTop(int x, int y) {
      final bottom = boxBottomByCol[x];
      if (bottom != null && y > bottom + 1) return bottom + 1;
      return y;
    }

    // 3. Standalone strokes (sequence lifelines) first: they sit beneath the
    // message arrows drawn in step 4.
    for (final shape in looseShapes) {
      _drawShape(canvas, shape, gx, gy, cellW, cellH, liftVerticalTop);
    }

    // 4. Edges: paths flattened to polylines, arrowheads, message labels.
    for (final group in edgeGroups) {
      final path = group.children.whereType<SceneShape>().firstWhereOrNull(
        (s) => s.geometry is PathGeometry,
      );
      if (path != null) {
        final points = _flatten(path.geometry as PathGeometry);
        for (var i = 0; i < points.length - 1; i++) {
          var x1 = gx(points[i].x);
          var y1 = gy(points[i].y);
          final x2 = gx(points[i + 1].x);
          final y2 = gy(points[i + 1].y);
          if (x1 == x2 && y2 > y1) y1 = liftVerticalTop(x1, y1);
          canvas.drawSegment(x1, y1, x2, y2, DiagramCellStyle.edge);
        }
        // Arrowhead: prefer the IR's marker polygon (it carries the true
        // direction), falling back to the path's final segment.
        final marker = group.children.whereType<SceneShape>().firstWhereOrNull(
          (s) => s.geometry is PolygonGeometry,
        );
        if (marker != null) {
          final m = _boundsOf(marker.geometry);
          final from = points.length >= 2 ? points[points.length - 2] : null;
          canvas.drawArrow(
            gx(m.left + m.width / 2),
            gy(m.top + m.height / 2),
            from == null
                ? DiagramDirection.right
                : _directionOf(
                    from,
                    Point(m.left + m.width / 2, m.top + m.height / 2),
                  ),
            DiagramCellStyle.edge,
          );
        } else if (points.length >= 2) {
          final from = points[points.length - 2];
          final to = points.last;
          canvas.drawArrow(
            gx(to.x),
            gy(to.y),
            _directionOf(from, to),
            DiagramCellStyle.edge,
          );
        }
      } else {
        // Edges without paths still contribute their strokes.
        for (final shape in group.children.whereType<SceneShape>()) {
          _drawShape(canvas, shape, gx, gy, cellW, cellH, liftVerticalTop);
        }
      }

      // Message labels live inside the edge group (sequence diagrams), not in
      // a separate edgeLabel group (flowcharts) — draw both.
      _drawTextRun(
        canvas,
        group.children.whereType<SceneText>().toList(),
        gx,
        gy,
        DiagramCellStyle.label,
      );
    }

    // 5. Edge label groups (flowcharts) and loose text on top.
    for (final group in edgeGroups) {
      if (group.role != SceneGroupRole.edgeLabel) continue;
      _drawTextRun(
        canvas,
        group.children.whereType<SceneText>().toList(),
        gx,
        gy,
        DiagramCellStyle.label,
      );
    }
    _drawTextRun(canvas, looseTexts, gx, gy, DiagramCellStyle.label);

    return canvas;
  }

  static SceneShape? _firstShape(SceneGroup group) =>
      group.children.whereType<SceneShape>().firstWhereOrNull(
        (s) => s.paintRole == ScenePaintRole.nodeBody,
      ) ??
      group.children.whereType<SceneShape>().firstOrNull;

  /// Union bounds of every shape in a node group. A sequence `actor` is a
  /// stick figure (torso path + head circle), not a box: bounds from the
  /// first shape alone sit on the torso, drawing the name box a row below
  /// the participants' boxes and colliding with the lifelines.
  static Rect _groupBounds(SceneGroup group, SceneShape body) {
    var bounds = _boundsOf(body.geometry);
    for (final shape in group.children.whereType<SceneShape>()) {
      if (identical(shape, body)) continue;
      final b = _boundsOf(shape.geometry);
      bounds = Rect.fromLTRB(
        math.min(bounds.left, b.left),
        math.min(bounds.top, b.top),
        math.max(bounds.right, b.right),
        math.max(bounds.bottom, b.bottom),
      );
    }
    return bounds;
  }

  static BoxFlavor _flavor(ShapeGeometry geometry, Rect bounds) {
    switch (geometry) {
      case EllipseGeometry():
      case CircleGeometry():
        return BoxFlavor.rounded;
      case PolygonGeometry(points: final points):
        final squareish =
            (bounds.width - bounds.height).abs() < bounds.width * 0.4;
        if (squareish && points.length <= 6) return BoxFlavor.rhombus;
        return BoxFlavor.square;
      default:
        return BoxFlavor.square;
    }
  }

  static void _drawShape(
    AsciiCanvas canvas,
    SceneShape shape,
    int Function(double) gx,
    int Function(double) gy,
    double cellW,
    double cellH, [
    int Function(int x, int y)? liftVerticalTop,
  ]) {
    final geometry = shape.geometry;
    if (geometry is PathGeometry) {
      final points = _flatten(geometry);
      for (var i = 0; i < points.length - 1; i++) {
        var x1 = gx(points[i].x);
        var y1 = gy(points[i].y);
        final x2 = gx(points[i + 1].x);
        final y2 = gy(points[i + 1].y);
        if (liftVerticalTop != null && x1 == x2 && y2 > y1) {
          y1 = liftVerticalTop(x1, y1);
        }
        canvas.drawSegment(x1, y1, x2, y2, DiagramCellStyle.edge);
      }
      return;
    }
    if (geometry is PolygonGeometry) {
      // Marker polygons (arrowheads) are covered by the arrow glyph drawn at
      // the path end, so they are skipped here.
      return;
    }
    final bounds = _boundsOf(geometry);
    canvas.drawBox(
      gx(bounds.left),
      gy(bounds.top),
      math.max(3, (bounds.width / cellW).round()),
      math.max(3, (bounds.height / cellH).round()),
      DiagramCellStyle.edge,
    );
  }

  /// Draws several texts as horizontal runs: texts sharing a row are laid out
  /// left to right with at least one blank cell between them, so sequence
  /// diagram autonumbers ("1") don't glue to their message labels.
  static void _drawTextRun(
    AsciiCanvas canvas,
    List<SceneText> texts,
    int Function(double) gx,
    int Function(double) gy,
    DiagramCellStyle style,
  ) {
    if (texts.isEmpty) return;
    final byRow = <int, List<SceneText>>{};
    for (final text in texts) {
      byRow.putIfAbsent(gy(text.bounds.top), () => <SceneText>[]).add(text);
    }
    for (final row in byRow.entries) {
      var cursor = -1;
      // Lay out in IR position order so autonumbers prefix their labels.
      final ordered = [...row.value]
        ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
      for (final text in ordered) {
        final bounds = text.bounds;
        // Bounds come from the text measurer (its own px-per-glyph advance),
        // not from the cell scale: dividing bounds.width by cellW yields a
        // bogus cell count. Anchor on the px center/right edge, shift by the
        // line's real character length.
        final centerPx = bounds.left + bounds.width / 2;
        final rightPx = bounds.left + bounds.width;
        final lines = text.text.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.isEmpty) continue;
          var x = switch (text.align) {
            TextAlignH.left => gx(bounds.left),
            TextAlignH.right => gx(rightPx) - line.length,
            TextAlignH.center => gx(centerPx) - line.length ~/ 2,
          };
          // Only the first line of each text lands on the group's row; keep
          // the run cursor scoped to it so multi-line continuation lines never
          // over-indent the next text.
          if (i == 0 && cursor >= 0 && x <= cursor) x = cursor + 1;
          canvas.putText(x, row.key + i, line, style);
          if (i == 0) cursor = x + line.length;
        }
      }
    }
  }

  static List<Point> _flatten(PathGeometry path) {
    final points = <Point>[];
    var current = const Point(0, 0);
    for (final command in path.commands) {
      switch (command) {
        case MoveTo(:final p):
          current = p;
          points.add(p);
        case LineTo(:final p):
          current = p;
          points.add(p);
        case QuadTo(:final c, :final p):
          for (var t = 1; t <= 12; t++) {
            points.add(_quad(current, c, p, t / 12));
          }
          current = p;
        case CubicTo(:final c1, :final c2, :final p):
          for (var t = 1; t <= 12; t++) {
            points.add(_cubic(current, c1, c2, p, t / 12));
          }
          current = p;
        case _:
          break;
      }
    }
    return points;
  }

  static Point _quad(Point p0, Point p1, Point p2, double t) {
    final u = 1 - t;
    return Point(
      u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
      u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
    );
  }

  static Point _cubic(Point p0, Point p1, Point p2, Point p3, double t) {
    final u = 1 - t;
    return Point(
      u * u * u * p0.x +
          3 * u * u * t * p1.x +
          3 * u * t * t * p2.x +
          t * t * t * p3.x,
      u * u * u * p0.y +
          3 * u * u * t * p1.y +
          3 * u * t * t * p2.y +
          t * t * t * p3.y,
    );
  }

  static DiagramDirection _directionOf(Point from, Point to) {
    final dx = (to.x - from.x).abs();
    final dy = (to.y - from.y).abs();
    if (dx >= dy) {
      return to.x >= from.x ? DiagramDirection.right : DiagramDirection.left;
    }
    return to.y >= from.y ? DiagramDirection.down : DiagramDirection.up;
  }

  static List<String> _wrapText(String text, int width) {
    if (width < 4) return [text];
    final lines = <String>[];
    for (final paragraph in text.split('\n')) {
      var current = '';
      for (final word in paragraph.split(' ')) {
        if (current.isEmpty) {
          current = word;
        } else if (current.length + 1 + word.length <= width) {
          current += ' $word';
        } else {
          lines.add(current);
          current = word;
        }
        while (current.length > width) {
          lines.add(current.substring(0, width));
          current = current.substring(width);
        }
      }
      if (current.isNotEmpty) lines.add(current);
    }
    return lines.isEmpty ? [''] : lines;
  }
}

/// Local re-declaration of scene bounds helpers (kept dependency-light).
Rect _boundsOf(ShapeGeometry geometry) => switch (geometry) {
  RectGeometry(:final rect) => rect,
  CircleGeometry(:final center, :final radius) => Rect.fromLTWH(
    center.x - radius,
    center.y - radius,
    radius * 2,
    radius * 2,
  ),
  EllipseGeometry(:final center, :final rx, :final ry) => Rect.fromLTWH(
    center.x - rx,
    center.y - ry,
    rx * 2,
    ry * 2,
  ),
  _ => geometryBounds(geometry),
};

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
