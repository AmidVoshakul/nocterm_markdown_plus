// ignore_for_file: experimental_member_use
import 'dart:convert';

import 'package:nocterm/nocterm.dart';

import '../theme/markdown_theme.dart';

/// Renders a markdown image (`![alt](src)`) as a block-level [Image].
///
/// Nocterm has no `WidgetSpan`, so images cannot live inside a `RichText`
/// paragraph: a standalone image paragraph is rendered as its own component
/// instead of an inline placeholder. Mixed paragraphs keep the
/// `[Image: alt]` placeholder produced by the visitor.
Component buildMarkdownImage({
  required String src,
  String? alt,
  int? width,
  ImageProtocol? protocol = ImageProtocol.unicodeBlocks,
  MarkdownTheme? theme,
}) {
  final label = alt?.isNotEmpty == true ? alt! : 'image';
  final resolvedProtocol = protocol ?? ImageProtocol.unicodeBlocks;
  final placeholderText = '[Image: $label]';
  final style = theme?.imageStyle?.toTextStyle();
  final placeholder = Text(placeholderText, style: style);
  final errorWidget = Text(placeholderText, style: style);

  if (src.startsWith('data:')) {
    final comma = src.indexOf(',');
    if (comma < 0) return placeholder;
    final meta = src.substring(5, comma);
    if (!meta.toLowerCase().contains('base64')) return placeholder;
    try {
      final bytes = base64Decode(src.substring(comma + 1));
      return Image.memory(
        bytes,
        width: width == null || width < 4 ? 4 : width,
        protocol: resolvedProtocol,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    } catch (_) {
      return placeholder;
    }
  }
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return Image.network(
      src,
      width: width == null || width < 4 ? 4 : width,
      protocol: protocol,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
  if (src.isEmpty) return placeholder;
  return Image.file(
    src,
    width: width == null || width < 4 ? 4 : width,
    protocol: protocol,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}
