// Theme quality gate: flags any theme slot whose foreground is unreadable on
// its background (invisible code / body text). Run: dart run tool/contrast_audit.dart
import 'dart:math' as math;

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';

double _luminance(Color c) {
  double channel(int v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  var failures = 0;
  for (final theme in MarkdownThemes.gallery.where((t) => t.name != 'ascii')) {
    // The ascii fallback is colorless by design — nothing to contrast-check.
    final bg = theme.background ?? const Color(0xFF000000);
    final codeBg = theme.codeBlockBackgroundStyle?.background ?? bg;
    final checks = <String, double>{
      'text': _contrast(theme.textStyle?.color ?? bg, bg),
      'codeBlock': _contrast(theme.codeBlockStyle?.color ?? bg, codeBg),
      'h1': _contrast(theme.h1Style?.color ?? bg, bg),
      'blockQuote': _contrast(theme.blockQuoteStyle?.color ?? bg, bg),
      'link': _contrast(theme.linkStyle?.color ?? bg, bg),
      'tableHeader': _contrast(theme.tableHeaderStyle?.color ?? bg, bg),
      'tableCell': _contrast(theme.tableCellStyle?.color ?? bg, bg),
      'syntaxComment': _contrast(
        theme.syntaxTheme?.comment?.color ?? bg,
        codeBg,
      ),
    };
    final min = checks.values.reduce(math.min);
    final weak = checks.entries.where((e) => e.value < 4.5).toList();
    if (weak.isEmpty) {
      print('OK   ${theme.name} (min ${min.toStringAsFixed(1)})');
    } else {
      failures++;
      print(
        'WEAK ${theme.name}: '
        '${weak.map((e) => '${e.key}=${e.value.toStringAsFixed(1)}').join(' ')}',
      );
    }
  }
  if (failures > 0) {
    throw StateError('$failures theme(s) below WCAG AA (4.5:1)');
  }
}
