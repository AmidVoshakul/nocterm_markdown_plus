import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('color mode', () {
    test('ansi256 quantizes theme colors', () {
      final theme = MarkdownThemes.catppuccinMocha;
      final quantized = theme.quantizedToAnsi256();
      // Quantized colors land on xterm-256 cube/ramp values.
      for (final style in [
        theme.textStyle!,
        theme.h1Style!,
        theme.codeStyle!,
      ]) {
        expect(style.color, isNotNull);
      }
      expect(quantized.name, theme.name);
      expect(quantized.textStyle!.color, isNotNull);
      // Cube colors have channel values from the 6-level ramp.
      final channels = [
        quantized.textStyle!.color!.red,
        quantized.textStyle!.color!.green,
        quantized.textStyle!.color!.blue,
      ];
      for (final channel in channels) {
        expect([0, 95, 135, 175, 215, 255].contains(channel), isTrue);
      }
    });
    test('exact grays quantize onto the gray ramp', () {
      // 0x808080 sits exactly on an xterm gray value; the quantizer must
      // keep it instead of snapping to the color cube.
      final theme = MarkdownThemes.nord.copyWith(
        textStyle: MarkdownStyle(color: Color(0xFF808080)),
      );
      expect(theme.quantizedToAnsi256().textStyle!.color, Color(0xFF808080));
    });
  });
}
