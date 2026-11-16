import "package:mermaid_core/mermaid_core.dart";
import "package:nocterm/nocterm.dart";

import '../render/code_block_renderer.dart';
import '../theme/markdown_theme.dart';
import 'ascii_canvas.dart';
import 'pie_renderer.dart';
import 'scene_rasterizer.dart';

/// Renders Mermaid diagrams (`mermaid` fenced blocks) as ASCII art.
/// Diagram types whose generic ASCII rendering is not yet acceptable.
/// These fall back to a source listing until a diagram-specific renderer
/// lands (see DESIGN.md D10, stage 2).
const _fallbackTypes = <DiagramType>{
  DiagramType.gantt,
  DiagramType.sankey,
  DiagramType.gitGraph,
  DiagramType.mindmap,
  DiagramType.journey,
};

class MermaidRenderer {
  const MermaidRenderer._();

  static InlineSpan render({
    required String code,
    required MarkdownTheme theme,
    int? maxWidth,
  }) {
    try {
      final type = detectDiagramType(code);
      if (_fallbackTypes.contains(type)) {
        return CodeBlockRenderer.render(
          code: code,
          language: 'mermaid',
          theme: theme,
        );
      }
      if (type == DiagramType.pie) {
        return PieRenderer.render(code: code, theme: theme, maxWidth: maxWidth);
      }
      final mermaid = const Mermaid(measurer: ApproximateTextMeasurer());
      final scene = mermaid.render(code);
      final orthogonal = type == DiagramType.flowchart;
      final canvas = SceneRasterizer.rasterize(
        scene,
        maxWidth: maxWidth,
        orthogonalEdges: orthogonal,
      );
      return _toSpan(canvas, theme);
    } catch (_) {
      return CodeBlockRenderer.render(
        code: code,
        language: 'mermaid',
        theme: theme,
      );
    }
  }

  static InlineSpan _toSpan(AsciiCanvas canvas, MarkdownTheme theme) {
    final nodeStyle = (theme.codeBlockStyle ?? theme.baseTextStyle)
        .merge(theme.codeBlockBackgroundStyle)
        .toTextStyle();
    final edgeStyle = (theme.horizontalRuleStyle ?? theme.baseTextStyle)
        .toTextStyle();
    final labelStyle = (theme.codeStyle ?? theme.baseTextStyle).toTextStyle();

    final children = <InlineSpan>[];
    for (final line in canvas.toStyledLines()) {
      for (final run in line) {
        final style = switch (run.style) {
          DiagramCellStyle.node => nodeStyle,
          DiagramCellStyle.edge => edgeStyle,
          DiagramCellStyle.label => labelStyle,
          DiagramCellStyle.plain => nodeStyle,
        };
        children.add(TextSpan(text: run.text, style: style));
      }
      children.add(const TextSpan(text: '\n'));
    }
    children.add(const TextSpan(text: '\n'));
    return TextSpan(children: children);
  }
}
