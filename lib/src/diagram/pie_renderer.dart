/// Renders Mermaid pie charts as a horizontal bar legend.
///
/// A pie slice has no meaningful ASCII shape (circles don't survive a
/// character grid), so we render the distribution as a fixed-width bar per
/// slice with a percentage and value column. This keeps the output aligned
/// regardless of label length.
library;

import 'package:mermaid_core/mermaid_core.dart';
import 'package:nocterm/nocterm.dart';

import '../theme/markdown_theme.dart';

class PieRenderer {
  const PieRenderer._();

  static const int _barWidth = 20;

  static InlineSpan render({
    required String code,
    required MarkdownTheme theme,
    int? maxWidth,
  }) {
    final chart = parsePieChart(code);
    final total = chart.slices.fold<double>(0, (s, sl) => s + sl.value);
    final labelStyle = (theme.codeStyle ?? theme.baseTextStyle).toTextStyle();
    final metaStyle = (theme.horizontalRuleStyle ?? theme.baseTextStyle)
        .toTextStyle();

    final children = <InlineSpan>[];
    if (chart.title != null && chart.title!.isNotEmpty) {
      children.add(
        TextSpan(
          text: '${chart.title}\n',
          style: (theme.h2Style ?? theme.baseTextStyle).toTextStyle(),
        ),
      );
      children.add(const TextSpan(text: '\n'));
    }

    final maxLabel = chart.slices.fold<int>(
      0,
      (m, sl) => sl.label.length > m ? sl.label.length : m,
    );

    for (final slice in chart.slices) {
      final pct = total > 0 ? slice.value / total : 0.0;
      final filled = (pct * _barWidth).round().clamp(0, _barWidth);
      final bar = '█' * filled + '░' * (_barWidth - filled);
      final paddedLabel = slice.label.padRight(maxLabel);
      final pctStr = '${(pct * 100).toStringAsFixed(1)}%'.padLeft(6);
      final valueStr = _formatValue(slice.value);
      children.add(
        TextSpan(
          text: '$paddedLabel  $bar  $pctStr  $valueStr\n',
          style: labelStyle,
        ),
      );
    }

    // Total line.
    children.add(
      TextSpan(
        text:
            '${'Total'.padRight(maxLabel)}  ${' ' * _barWidth}  ${'100.0%'.padLeft(6)}  ${_formatValue(total)}\n',
        style: metaStyle,
      ),
    );
    children.add(const TextSpan(text: '\n'));

    return TextSpan(children: children);
  }

  static String _formatValue(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
