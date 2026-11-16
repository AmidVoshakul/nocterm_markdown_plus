import 'package:nocterm_markdown_plus/src/diagram/ascii_canvas.dart';
import 'package:test/test.dart';

void main() {
  group('AsciiCanvas', () {
    test('drawBox supports rounded and rhombus flavors', () {
      final canvas = AsciiCanvas(6, 4);
      canvas.drawBox(
        0,
        0,
        6,
        4,
        DiagramCellStyle.node,
        flavor: BoxFlavor.rounded,
      );
      expect(canvas.charAt(0, 0), '╭');
      expect(canvas.charAt(5, 0), '╮');
      expect(canvas.charAt(0, 3), '╰');
      expect(canvas.charAt(5, 3), '╯');

      final canvas2 = AsciiCanvas(6, 4);
      canvas2.drawBox(
        0,
        0,
        6,
        4,
        DiagramCellStyle.node,
        flavor: BoxFlavor.rhombus,
      );
      expect(canvas2.charAt(0, 0), '╱');
    });

    test('drawBox ignores too-small boxes', () {
      final canvas = AsciiCanvas(4, 4);
      canvas.drawBox(0, 0, 1, 4, DiagramCellStyle.node);
      expect(canvas.charAt(0, 0), ' ');
    });

    test('drawSegment draws horizontal, vertical and diagonal', () {
      final canvas = AsciiCanvas(6, 6);
      canvas.drawSegment(0, 0, 3, 0, DiagramCellStyle.edge);
      expect(canvas.charAt(1, 0), '─');
      canvas.drawSegment(0, 0, 0, 3, DiagramCellStyle.edge);
      expect(canvas.charAt(0, 1), '│');
      final canvas2 = AsciiCanvas(6, 6);
      canvas2.drawSegment(0, 0, 3, 3, DiagramCellStyle.edge);
      expect(canvas2.charAt(1, 1), isNotNull);
    });

    test('drawSegment skips protected cells', () {
      final canvas = AsciiCanvas(6, 4);
      canvas.drawBox(1, 0, 4, 4, DiagramCellStyle.node);
      canvas.drawSegment(0, 1, 5, 1, DiagramCellStyle.edge);
      expect(canvas.charAt(1, 1), '│');
    });

    test('putText and charAt/styleAt handle bounds', () {
      final canvas = AsciiCanvas(4, 2);
      canvas.putText(1, 0, 'ab', DiagramCellStyle.label);
      expect(canvas.charAt(1, 0), 'a');
      expect(canvas.charAt(2, 0), 'b');
      expect(canvas.charAt(-1, 0), ' ');
      expect(canvas.charAt(10, 10), ' ');
      expect(canvas.styleAt(-1, 0), DiagramCellStyle.plain);
      expect(canvas.styleAt(1, 0), DiagramCellStyle.label);
    });

    test('drawArrow draws all directions', () {
      final canvas = AsciiCanvas(4, 4);
      canvas.drawArrow(0, 0, DiagramDirection.right, DiagramCellStyle.edge);
      canvas.drawArrow(1, 1, DiagramDirection.left, DiagramCellStyle.edge);
      canvas.drawArrow(2, 2, DiagramDirection.down, DiagramCellStyle.edge);
      canvas.drawArrow(3, 3, DiagramDirection.up, DiagramCellStyle.edge);
      expect(canvas.charAt(0, 0), '►');
      expect(canvas.charAt(1, 1), '◄');
      expect(canvas.charAt(2, 2), '▼');
      expect(canvas.charAt(3, 3), '▲');
    });

    test('toLines and toStyledLines reflect cells', () {
      final canvas = AsciiCanvas(3, 2);
      canvas.put(0, 0, 'x', DiagramCellStyle.node);
      expect(canvas.toLines(), ['x  ', '   ']);
      final styled = canvas.toStyledLines();
      expect(styled.length, 2);
      expect(styled[0].map((r) => r.text).join(), 'x  ');
    });

    test('merge line crosses horizontal and vertical', () {
      final canvas = AsciiCanvas(3, 3);
      canvas.drawSegment(0, 1, 2, 1, DiagramCellStyle.edge);
      canvas.drawSegment(1, 0, 1, 2, DiagramCellStyle.edge);
      expect(canvas.charAt(1, 1), '┼');
    });
  });
}
