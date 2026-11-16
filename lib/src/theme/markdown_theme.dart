import 'package:nocterm/nocterm.dart';

import 'no_color.dart';

/// A single style inside a [MarkdownTheme].
///
/// Styles are small, immutable value objects so they can be composed,
/// compared, and serialized without depending on widget internals.
class MarkdownStyle {
  const MarkdownStyle({
    this.color,
    this.background,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.prefix,
    this.suffix,
  });

  const MarkdownStyle.all(this.color)
    : background = null,
      bold = false,
      italic = false,
      underline = false,
      strikethrough = false,
      prefix = null,
      suffix = null;

  static const MarkdownStyle empty = MarkdownStyle();

  final Color? color;
  final Color? background;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  /// Glyphs rendered around the content (`prefix`/`suffix`).
  final String? prefix;
  final String? suffix;

  MarkdownStyle copyWith({
    Color? color,
    Color? background,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? prefix,
    String? suffix,
  }) {
    return MarkdownStyle(
      color: color ?? this.color,
      background: background ?? this.background,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
    );
  }

  /// Returns a copy whose colours are blended toward [base] by [factor],
  /// making the whole style less prominent (e.g. 50% dimmer for LLM
  /// "thinking" output). Emphasis flags and glyphs are preserved.
  MarkdownStyle dimmed(Color base, {double factor = 0.5}) {
    return MarkdownStyle(
      color: color == null ? null : blendColors(color!, base, factor),
      background: background == null
          ? null
          : blendColors(background!, base, factor),
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      prefix: prefix,
      suffix: suffix,
    );
  }

  TextStyle toTextStyle() {
    final noColor = NoColor.enabled;
    return TextStyle(
      color: noColor ? null : color,
      backgroundColor: noColor ? null : background,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: underline
          ? TextDecoration.underline
          : strikethrough
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );
  }

  /// Merges this style with [other].
  ///
  /// [other] wins for colors; emphasis flags are additive (either side can
  /// turn bold/italic/underline/strikethrough on).
  MarkdownStyle merge(MarkdownStyle? other) {
    if (other == null) return this;
    return MarkdownStyle(
      color: other.color ?? color,
      background: other.background ?? background,
      bold: other.bold || bold,
      italic: other.italic || italic,
      underline: other.underline || underline,
      strikethrough: other.strikethrough || strikethrough,
      prefix: other.prefix ?? prefix,
      suffix: other.suffix ?? suffix,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (color != null) 'color': _hex(color!),
      if (background != null) 'background': _hex(background!),
      if (bold) 'bold': true,
      if (italic) 'italic': true,
      if (underline) 'underline': true,
      if (strikethrough) 'strikethrough': true,
      if (prefix != null) 'prefix': prefix,
      if (suffix != null) 'suffix': suffix,
    };
  }

  static MarkdownStyle fromJson(Map<String, dynamic> json) {
    return MarkdownStyle(
      color: _parseHex(json['color'] as String?),
      background: _parseHex(json['background'] as String?),
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      strikethrough: json['strikethrough'] as bool? ?? false,
      prefix: json['prefix'] as String?,
      suffix: json['suffix'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownStyle &&
        other.color == color &&
        other.background == background &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough &&
        other.prefix == prefix &&
        other.suffix == suffix;
  }

  @override
  int get hashCode => Object.hash(
    color,
    background,
    bold,
    italic,
    underline,
    strikethrough,
    prefix,
    suffix,
  );

  @override
  String toString() => 'MarkdownStyle(${toJson()})';
}

/// Syntax highlighting slots used when a rich per-token theme is not
/// available (see `CodeHighlighter` adapters for rich themes).
class SyntaxTheme {
  const SyntaxTheme({
    this.keyword,
    this.string,
    this.number,
    this.comment,
    this.function,
    this.variable,
    this.type,
    this.operator,
    this.punctuation,
    this.plain,
  });

  final MarkdownStyle? keyword;
  final MarkdownStyle? string;
  final MarkdownStyle? number;
  final MarkdownStyle? comment;
  final MarkdownStyle? function;
  final MarkdownStyle? variable;
  final MarkdownStyle? type;
  final MarkdownStyle? operator;
  final MarkdownStyle? punctuation;
  final MarkdownStyle? plain;

  SyntaxTheme copyWith({
    MarkdownStyle? keyword,
    MarkdownStyle? string,
    MarkdownStyle? number,
    MarkdownStyle? comment,
    MarkdownStyle? function,
    MarkdownStyle? variable,
    MarkdownStyle? type,
    MarkdownStyle? operator,
    MarkdownStyle? punctuation,
    MarkdownStyle? plain,
  }) {
    return SyntaxTheme(
      keyword: keyword ?? this.keyword,
      string: string ?? this.string,
      number: number ?? this.number,
      comment: comment ?? this.comment,
      function: function ?? this.function,
      variable: variable ?? this.variable,
      type: type ?? this.type,
      operator: operator ?? this.operator,
      punctuation: punctuation ?? this.punctuation,
      plain: plain ?? this.plain,
    );
  }

  SyntaxTheme dimmed(Color base, {double factor = 0.5}) {
    MarkdownStyle? d(MarkdownStyle? s) => s?.dimmed(base, factor: factor);
    return SyntaxTheme(
      keyword: d(keyword),
      string: d(string),
      number: d(number),
      comment: d(comment),
      function: d(function),
      variable: d(variable),
      type: d(type),
      operator: d(operator),
      punctuation: d(punctuation),
      plain: d(plain),
    );
  }

  Map<String, dynamic> toJson() => {
    'keyword': keyword?.toJson(),
    'string': string?.toJson(),
    'number': number?.toJson(),
    'comment': comment?.toJson(),
    'function': function?.toJson(),
    'variable': variable?.toJson(),
    'type': type?.toJson(),
    'operator': operator?.toJson(),
    'punctuation': punctuation?.toJson(),
    'plain': plain?.toJson(),
  };

  static SyntaxTheme fromJson(Map<String, dynamic> json) {
    MarkdownStyle? s(String key) => json[key] is Map<String, dynamic>
        ? MarkdownStyle.fromJson(json[key] as Map<String, dynamic>)
        : null;
    return SyntaxTheme(
      keyword: s('keyword'),
      string: s('string'),
      number: s('number'),
      comment: s('comment'),
      function: s('function'),
      variable: s('variable'),
      type: s('type'),
      operator: s('operator'),
      punctuation: s('punctuation'),
      plain: s('plain'),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyntaxTheme &&
        other.keyword == keyword &&
        other.string == string &&
        other.number == number &&
        other.comment == comment &&
        other.function == function &&
        other.variable == variable &&
        other.type == type &&
        other.operator == operator &&
        other.punctuation == punctuation &&
        other.plain == plain;
  }

  @override
  int get hashCode => Object.hash(
    keyword,
    string,
    number,
    comment,
    function,
    variable,
    type,
    operator,
    punctuation,
    plain,
  );
}

/// A complete theme for `MarkdownPlus`.
///
/// Slots give every markdown element its own style. Every slot is optional —
/// the visitor falls back through the chain
/// `slot ?? broader slot ?? textStyle`.
class MarkdownTheme {
  const MarkdownTheme({
    required this.name,
    required this.brightness,
    this.background,
    this.textStyle,
    this.paragraphStyle,
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.strongStyle,
    this.emphStyle,
    this.delStyle,
    this.codeStyle,
    this.codeBackgroundStyle,
    this.codeBlockStyle,
    this.codeBlockBackgroundStyle,
    this.blockQuoteStyle,
    this.blockQuoteBarStyle,
    this.linkStyle,
    this.linkTextStyle,
    this.listBulletStyle,
    this.listEnumerationStyle,
    this.horizontalRuleStyle,
    this.tableHeaderStyle,
    this.tableBorderStyle,
    this.tableCellStyle,
    this.imageStyle,
    this.imageTextStyle,
    this.taskCheckedStyle,
    this.taskUncheckedStyle,
    this.definitionListStyle,
    this.definitionTermStyle,
    this.definitionDescriptionStyle,
    this.alertNoteStyle,
    this.alertTipStyle,
    this.alertImportantStyle,
    this.alertWarningStyle,
    this.alertCautionStyle,
    this.footnoteRefStyle,
    this.footnoteDefinitionStyle,
    this.diffAddedStyle,
    this.diffRemovedStyle,
    this.diffHunkStyle,
    this.diffMetaStyle,
    this.syntaxTheme,
    this.bulletGlyph = '• ',
    this.horizontalRuleChar = '─',
    this.taskCheckedGlyph = '☑ ',
    this.taskUncheckedGlyph = '☐ ',
  });

  final String name;
  final Brightness brightness;

  /// Background color for the rendered markdown surface.
  ///
  /// `MarkdownPlus` paints its area with this color so rendered blocks (e.g.
  /// code blocks) and the page share one coherent background.
  final Color? background;

  final MarkdownStyle? textStyle;
  final MarkdownStyle? paragraphStyle;
  final MarkdownStyle? h1Style;
  final MarkdownStyle? h2Style;
  final MarkdownStyle? h3Style;
  final MarkdownStyle? h4Style;
  final MarkdownStyle? h5Style;
  final MarkdownStyle? h6Style;
  final MarkdownStyle? strongStyle;
  final MarkdownStyle? emphStyle;
  final MarkdownStyle? delStyle;
  final MarkdownStyle? codeStyle;
  final MarkdownStyle? codeBackgroundStyle;
  final MarkdownStyle? codeBlockStyle;
  final MarkdownStyle? codeBlockBackgroundStyle;
  final MarkdownStyle? blockQuoteStyle;
  final MarkdownStyle? blockQuoteBarStyle;
  final MarkdownStyle? linkStyle;
  final MarkdownStyle? linkTextStyle;
  final MarkdownStyle? listBulletStyle;
  final MarkdownStyle? listEnumerationStyle;
  final MarkdownStyle? horizontalRuleStyle;
  final MarkdownStyle? tableHeaderStyle;
  final MarkdownStyle? tableBorderStyle;
  final MarkdownStyle? tableCellStyle;
  final MarkdownStyle? imageStyle;

  /// Style of the alt text inside an image placeholder.
  final MarkdownStyle? imageTextStyle;

  /// Styles for task lists (glyphs via `prefix`).
  final MarkdownStyle? taskCheckedStyle;
  final MarkdownStyle? taskUncheckedStyle;

  /// Styles for definition lists.
  final MarkdownStyle? definitionListStyle;
  final MarkdownStyle? definitionTermStyle;
  final MarkdownStyle? definitionDescriptionStyle;

  /// Styles for GitHub alerts (`> [!NOTE]` and friends). The icon rides in
  /// the style's `prefix`.
  final MarkdownStyle? alertNoteStyle;
  final MarkdownStyle? alertTipStyle;
  final MarkdownStyle? alertImportantStyle;
  final MarkdownStyle? alertWarningStyle;
  final MarkdownStyle? alertCautionStyle;

  /// Styles for footnotes.
  final MarkdownStyle? footnoteRefStyle;
  final MarkdownStyle? footnoteDefinitionStyle;

  /// Styles for `diff`/`patch` fenced blocks.
  final MarkdownStyle? diffAddedStyle;
  final MarkdownStyle? diffRemovedStyle;
  final MarkdownStyle? diffHunkStyle;
  final MarkdownStyle? diffMetaStyle;

  final SyntaxTheme? syntaxTheme;

  final String bulletGlyph;
  final String horizontalRuleChar;
  final String taskCheckedGlyph;
  final String taskUncheckedGlyph;

  /// Resolved base text style (empty when a theme is fully custom).
  MarkdownStyle get baseTextStyle =>
      textStyle ?? paragraphStyle ?? MarkdownStyle.empty;

  MarkdownTheme copyWith({
    String? name,
    Brightness? brightness,
    Color? background,
    MarkdownStyle? textStyle,
    MarkdownStyle? paragraphStyle,
    MarkdownStyle? h1Style,
    MarkdownStyle? h2Style,
    MarkdownStyle? h3Style,
    MarkdownStyle? h4Style,
    MarkdownStyle? h5Style,
    MarkdownStyle? h6Style,
    MarkdownStyle? strongStyle,
    MarkdownStyle? emphStyle,
    MarkdownStyle? delStyle,
    MarkdownStyle? codeStyle,
    MarkdownStyle? codeBackgroundStyle,
    MarkdownStyle? codeBlockStyle,
    MarkdownStyle? codeBlockBackgroundStyle,
    MarkdownStyle? blockQuoteStyle,
    MarkdownStyle? blockQuoteBarStyle,
    MarkdownStyle? linkStyle,
    MarkdownStyle? linkTextStyle,
    MarkdownStyle? listBulletStyle,
    MarkdownStyle? listEnumerationStyle,
    MarkdownStyle? horizontalRuleStyle,
    MarkdownStyle? tableHeaderStyle,
    MarkdownStyle? tableBorderStyle,
    MarkdownStyle? tableCellStyle,
    MarkdownStyle? imageStyle,
    MarkdownStyle? imageTextStyle,
    MarkdownStyle? taskCheckedStyle,
    MarkdownStyle? taskUncheckedStyle,
    MarkdownStyle? definitionListStyle,
    MarkdownStyle? definitionTermStyle,
    MarkdownStyle? definitionDescriptionStyle,
    MarkdownStyle? alertNoteStyle,
    MarkdownStyle? alertTipStyle,
    MarkdownStyle? alertImportantStyle,
    MarkdownStyle? alertWarningStyle,
    MarkdownStyle? alertCautionStyle,
    MarkdownStyle? footnoteRefStyle,
    MarkdownStyle? footnoteDefinitionStyle,
    MarkdownStyle? diffAddedStyle,
    MarkdownStyle? diffRemovedStyle,
    MarkdownStyle? diffHunkStyle,
    MarkdownStyle? diffMetaStyle,
    SyntaxTheme? syntaxTheme,
    String? bulletGlyph,
    String? horizontalRuleChar,
    String? taskCheckedGlyph,
    String? taskUncheckedGlyph,
  }) {
    return MarkdownTheme(
      name: name ?? this.name,
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      textStyle: textStyle ?? this.textStyle,
      paragraphStyle: paragraphStyle ?? this.paragraphStyle,
      h1Style: h1Style ?? this.h1Style,
      h2Style: h2Style ?? this.h2Style,
      h3Style: h3Style ?? this.h3Style,
      h4Style: h4Style ?? this.h4Style,
      h5Style: h5Style ?? this.h5Style,
      h6Style: h6Style ?? this.h6Style,
      strongStyle: strongStyle ?? this.strongStyle,
      emphStyle: emphStyle ?? this.emphStyle,
      delStyle: delStyle ?? this.delStyle,
      codeStyle: codeStyle ?? this.codeStyle,
      codeBackgroundStyle: codeBackgroundStyle ?? this.codeBackgroundStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      codeBlockBackgroundStyle:
          codeBlockBackgroundStyle ?? this.codeBlockBackgroundStyle,
      blockQuoteStyle: blockQuoteStyle ?? this.blockQuoteStyle,
      blockQuoteBarStyle: blockQuoteBarStyle ?? this.blockQuoteBarStyle,
      linkStyle: linkStyle ?? this.linkStyle,
      linkTextStyle: linkTextStyle ?? this.linkTextStyle,
      listBulletStyle: listBulletStyle ?? this.listBulletStyle,
      listEnumerationStyle: listEnumerationStyle ?? this.listEnumerationStyle,
      horizontalRuleStyle: horizontalRuleStyle ?? this.horizontalRuleStyle,
      tableHeaderStyle: tableHeaderStyle ?? this.tableHeaderStyle,
      tableBorderStyle: tableBorderStyle ?? this.tableBorderStyle,
      tableCellStyle: tableCellStyle ?? this.tableCellStyle,
      imageStyle: imageStyle ?? this.imageStyle,
      imageTextStyle: imageTextStyle ?? this.imageTextStyle,
      taskCheckedStyle: taskCheckedStyle ?? this.taskCheckedStyle,
      taskUncheckedStyle: taskUncheckedStyle ?? this.taskUncheckedStyle,
      definitionListStyle: definitionListStyle ?? this.definitionListStyle,
      definitionTermStyle: definitionTermStyle ?? this.definitionTermStyle,
      definitionDescriptionStyle:
          definitionDescriptionStyle ?? this.definitionDescriptionStyle,
      alertNoteStyle: alertNoteStyle ?? this.alertNoteStyle,
      alertTipStyle: alertTipStyle ?? this.alertTipStyle,
      alertImportantStyle: alertImportantStyle ?? this.alertImportantStyle,
      alertWarningStyle: alertWarningStyle ?? this.alertWarningStyle,
      alertCautionStyle: alertCautionStyle ?? this.alertCautionStyle,
      footnoteRefStyle: footnoteRefStyle ?? this.footnoteRefStyle,
      footnoteDefinitionStyle:
          footnoteDefinitionStyle ?? this.footnoteDefinitionStyle,
      diffAddedStyle: diffAddedStyle ?? this.diffAddedStyle,
      diffRemovedStyle: diffRemovedStyle ?? this.diffRemovedStyle,
      diffHunkStyle: diffHunkStyle ?? this.diffHunkStyle,
      diffMetaStyle: diffMetaStyle ?? this.diffMetaStyle,
      syntaxTheme: syntaxTheme ?? this.syntaxTheme,
      bulletGlyph: bulletGlyph ?? this.bulletGlyph,
      horizontalRuleChar: horizontalRuleChar ?? this.horizontalRuleChar,
      taskCheckedGlyph: taskCheckedGlyph ?? this.taskCheckedGlyph,
      taskUncheckedGlyph: taskUncheckedGlyph ?? this.taskUncheckedGlyph,
    );
  }

  /// Derives a markdown theme from an app-level nocterm [TuiThemeData],
  /// keeping rendered markdown visually consistent with the host app.
  factory MarkdownTheme.fromTuiTheme(TuiThemeData data, {String? name}) {
    // Darken accent roles on light themes — the core palette's accents are
    // tuned for mid-tone surfaces and fall below AA on light backgrounds.
    final light = data.brightness == Brightness.light;
    Color accent(Color c) => light ? _scaled(c, 0.82) : c;
    final primary = accent(data.primary);
    final secondary = accent(data.secondary);
    // Plain text should sit one step away from the background: lighter on
    // dark themes, darker on light themes, so paragraphs stay readable.
    final baseText = light
        ? _scaled(data.onSurface, 0.78)
        : blendColors(data.onSurface, const Color(0xFFFFFFFF), 0.16);
    return MarkdownTheme(
      name: name ?? 'tui-theme',
      brightness: data.brightness,
      background: data.background,
      textStyle: MarkdownStyle.all(baseText),
      h1Style: MarkdownStyle.all(primary).copyWith(bold: true),
      h2Style: MarkdownStyle.all(primary).copyWith(bold: true),
      h3Style: MarkdownStyle.all(secondary).copyWith(bold: true),
      h4Style: MarkdownStyle.all(data.onSurface).copyWith(bold: true),
      h5Style: MarkdownStyle.all(data.onSurface).copyWith(bold: true),
      h6Style: MarkdownStyle.all(data.onSurface).copyWith(bold: true),
      strongStyle: MarkdownStyle.all(data.warning).copyWith(bold: true),
      emphStyle: MarkdownStyle.all(data.warning).copyWith(italic: true),
      delStyle: MarkdownStyle.all(data.outline).copyWith(strikethrough: true),
      codeStyle: MarkdownStyle.all(data.success),
      codeBackgroundStyle: MarkdownStyle(background: data.background),
      codeBlockStyle: MarkdownStyle.all(data.onSurface),
      codeBlockBackgroundStyle: MarkdownStyle(background: data.background),
      blockQuoteStyle: MarkdownStyle.all(data.outline).copyWith(italic: true),
      blockQuoteBarStyle: MarkdownStyle.all(data.secondary),
      linkStyle: MarkdownStyle.all(primary).copyWith(underline: true),
      linkTextStyle: MarkdownStyle.all(secondary),
      listBulletStyle: MarkdownStyle.all(secondary),
      listEnumerationStyle: MarkdownStyle.all(primary),
      horizontalRuleStyle: MarkdownStyle.all(data.outlineVariant),
      tableHeaderStyle: MarkdownStyle.all(primary).copyWith(bold: true),
      tableBorderStyle: MarkdownStyle.all(data.outlineVariant),
      tableCellStyle: MarkdownStyle.all(data.onSurface),
      imageStyle: MarkdownStyle.all(secondary).copyWith(italic: true),
      imageTextStyle: MarkdownStyle.all(secondary),
      taskCheckedStyle: const MarkdownStyle(prefix: '☑ ')
          .copyWith(color: accent(data.success)),
      taskUncheckedStyle: const MarkdownStyle(prefix: '☐ ')
          .copyWith(color: accent(data.outline)),
      definitionListStyle: MarkdownStyle.all(data.onSurface),
      definitionTermStyle: MarkdownStyle.all(primary).copyWith(bold: true),
      definitionDescriptionStyle: MarkdownStyle.all(data.onSurface),
      alertNoteStyle: const MarkdownStyle(prefix: 'ℹ ')
          .copyWith(color: accent(data.primary)),
      alertTipStyle: const MarkdownStyle(prefix: '💡 ')
          .copyWith(color: accent(data.success)),
      alertImportantStyle: const MarkdownStyle(prefix: '❗ ')
          .copyWith(color: accent(data.secondary)),
      alertWarningStyle: const MarkdownStyle(prefix: '⚠ ')
          .copyWith(color: accent(data.warning)),
      alertCautionStyle: const MarkdownStyle(prefix: '🔥 ')
          .copyWith(color: accent(data.error)),
      footnoteRefStyle: const MarkdownStyle(
        prefix: '[',
        suffix: ']',
      ).copyWith(color: secondary),
      footnoteDefinitionStyle: MarkdownStyle.all(data.outline),
      diffAddedStyle: MarkdownStyle(
        color: data.onSurface,
        background: blendColors(data.background, accent(data.success), 0.22),
      ),
      diffRemovedStyle: MarkdownStyle(
        color: data.onSurface,
        background: blendColors(data.background, accent(data.error), 0.22),
      ),
      diffHunkStyle: MarkdownStyle.all(accent(data.warning)),
      diffMetaStyle: MarkdownStyle.all(data.outline),
      syntaxTheme: SyntaxTheme(
        keyword: MarkdownStyle.all(data.primary),
        string: MarkdownStyle.all(data.success),
        number: MarkdownStyle.all(data.warning),
        comment: MarkdownStyle.all(data.outline),
        function: MarkdownStyle.all(data.secondary),
        variable: MarkdownStyle.all(data.onSurface),
        type: MarkdownStyle.all(data.secondary),
        operator: MarkdownStyle.all(data.primary),
        punctuation: MarkdownStyle.all(data.outline),
        plain: MarkdownStyle.all(data.onSurface),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'brightness': brightness == Brightness.dark ? 'dark' : 'light',
    'background': background == null ? null : _hex(background!),
    'text': textStyle?.toJson(),
    'paragraph': paragraphStyle?.toJson(),
    'h1': h1Style?.toJson(),
    'h2': h2Style?.toJson(),
    'h3': h3Style?.toJson(),
    'h4': h4Style?.toJson(),
    'h5': h5Style?.toJson(),
    'h6': h6Style?.toJson(),
    'strong': strongStyle?.toJson(),
    'emph': emphStyle?.toJson(),
    'del': delStyle?.toJson(),
    'code': codeStyle?.toJson(),
    'codeBackground': codeBackgroundStyle?.toJson(),
    'codeBlock': codeBlockStyle?.toJson(),
    'codeBlockBackground': codeBlockBackgroundStyle?.toJson(),
    'blockQuote': blockQuoteStyle?.toJson(),
    'blockQuoteBar': blockQuoteBarStyle?.toJson(),
    'link': linkStyle?.toJson(),
    'linkText': linkTextStyle?.toJson(),
    'listBullet': listBulletStyle?.toJson(),
    'listEnumeration': listEnumerationStyle?.toJson(),
    'horizontalRule': horizontalRuleStyle?.toJson(),
    'tableHeader': tableHeaderStyle?.toJson(),
    'tableBorder': tableBorderStyle?.toJson(),
    'tableCell': tableCellStyle?.toJson(),
    'image': imageStyle?.toJson(),
    'imageText': imageTextStyle?.toJson(),
    'taskChecked': taskCheckedStyle?.toJson(),
    'taskUnchecked': taskUncheckedStyle?.toJson(),
    'definitionList': definitionListStyle?.toJson(),
    'definitionTerm': definitionTermStyle?.toJson(),
    'definitionDescription': definitionDescriptionStyle?.toJson(),
    'alertNote': alertNoteStyle?.toJson(),
    'alertTip': alertTipStyle?.toJson(),
    'alertImportant': alertImportantStyle?.toJson(),
    'alertWarning': alertWarningStyle?.toJson(),
    'alertCaution': alertCautionStyle?.toJson(),
    'footnoteRef': footnoteRefStyle?.toJson(),
    'footnoteDefinition': footnoteDefinitionStyle?.toJson(),
    'diffAdded': diffAddedStyle?.toJson(),
    'diffRemoved': diffRemovedStyle?.toJson(),
    'diffHunk': diffHunkStyle?.toJson(),
    'diffMeta': diffMetaStyle?.toJson(),
    'syntax': syntaxTheme?.toJson(),
    'glyphs': {
      'bullet': bulletGlyph,
      'horizontalRule': horizontalRuleChar,
      'taskChecked': taskCheckedGlyph,
      'taskUnchecked': taskUncheckedGlyph,
    },
  };

  static MarkdownTheme fromJson(Map<String, dynamic> json) {
    MarkdownStyle? s(String key) => json[key] is Map<String, dynamic>
        ? MarkdownStyle.fromJson(json[key] as Map<String, dynamic>)
        : null;
    final glyphs = json['glyphs'] as Map<String, dynamic>? ?? const {};
    return MarkdownTheme(
      name: json['name'] as String? ?? 'custom',
      brightness: json['brightness'] == 'light'
          ? Brightness.light
          : Brightness.dark,
      background: _parseHex(json['background'] as String?),
      textStyle: s('text'),
      paragraphStyle: s('paragraph'),
      h1Style: s('h1'),
      h2Style: s('h2'),
      h3Style: s('h3'),
      h4Style: s('h4'),
      h5Style: s('h5'),
      h6Style: s('h6'),
      strongStyle: s('strong'),
      emphStyle: s('emph'),
      delStyle: s('del'),
      codeStyle: s('code'),
      codeBackgroundStyle: s('codeBackground'),
      codeBlockStyle: s('codeBlock'),
      codeBlockBackgroundStyle: s('codeBlockBackground'),
      blockQuoteStyle: s('blockQuote'),
      blockQuoteBarStyle: s('blockQuoteBar'),
      linkStyle: s('link'),
      linkTextStyle: s('linkText'),
      listBulletStyle: s('listBullet'),
      listEnumerationStyle: s('listEnumeration'),
      horizontalRuleStyle: s('horizontalRule'),
      tableHeaderStyle: s('tableHeader'),
      tableBorderStyle: s('tableBorder'),
      tableCellStyle: s('tableCell'),
      imageStyle: s('image'),
      imageTextStyle: s('imageText'),
      taskCheckedStyle: s('taskChecked'),
      taskUncheckedStyle: s('taskUnchecked'),
      definitionListStyle: s('definitionList'),
      definitionTermStyle: s('definitionTerm'),
      definitionDescriptionStyle: s('definitionDescription'),
      alertNoteStyle: s('alertNote'),
      alertTipStyle: s('alertTip'),
      alertImportantStyle: s('alertImportant'),
      alertWarningStyle: s('alertWarning'),
      alertCautionStyle: s('alertCaution'),
      footnoteRefStyle: s('footnoteRef'),
      footnoteDefinitionStyle: s('footnoteDefinition'),
      diffAddedStyle: s('diffAdded'),
      diffRemovedStyle: s('diffRemoved'),
      diffHunkStyle: s('diffHunk'),
      diffMetaStyle: s('diffMeta'),
      syntaxTheme: json['syntax'] is Map<String, dynamic>
          ? SyntaxTheme.fromJson(json['syntax'] as Map<String, dynamic>)
          : null,
      bulletGlyph: glyphs['bullet'] as String? ?? '• ',
      horizontalRuleChar: glyphs['horizontalRule'] as String? ?? '─',
      taskCheckedGlyph: glyphs['taskChecked'] as String? ?? '☑ ',
      taskUncheckedGlyph: glyphs['taskUnchecked'] as String? ?? '☐ ',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownTheme &&
        other.name == name &&
        other.brightness == brightness &&
        other.background == background &&
        _slotsEqual(other);
  }

  bool _slotsEqual(MarkdownTheme other) =>
      textStyle == other.textStyle &&
      paragraphStyle == other.paragraphStyle &&
      h1Style == other.h1Style &&
      h2Style == other.h2Style &&
      h3Style == other.h3Style &&
      h4Style == other.h4Style &&
      h5Style == other.h5Style &&
      h6Style == other.h6Style &&
      strongStyle == other.strongStyle &&
      emphStyle == other.emphStyle &&
      delStyle == other.delStyle &&
      codeStyle == other.codeStyle &&
      codeBackgroundStyle == other.codeBackgroundStyle &&
      codeBlockStyle == other.codeBlockStyle &&
      codeBlockBackgroundStyle == other.codeBlockBackgroundStyle &&
      blockQuoteStyle == other.blockQuoteStyle &&
      blockQuoteBarStyle == other.blockQuoteBarStyle &&
      linkStyle == other.linkStyle &&
      linkTextStyle == other.linkTextStyle &&
      listBulletStyle == other.listBulletStyle &&
      listEnumerationStyle == other.listEnumerationStyle &&
      horizontalRuleStyle == other.horizontalRuleStyle &&
      tableHeaderStyle == other.tableHeaderStyle &&
      tableBorderStyle == other.tableBorderStyle &&
      tableCellStyle == other.tableCellStyle &&
      imageStyle == other.imageStyle &&
      imageTextStyle == other.imageTextStyle &&
      taskCheckedStyle == other.taskCheckedStyle &&
      taskUncheckedStyle == other.taskUncheckedStyle &&
      definitionListStyle == other.definitionListStyle &&
      definitionTermStyle == other.definitionTermStyle &&
      definitionDescriptionStyle == other.definitionDescriptionStyle &&
      alertNoteStyle == other.alertNoteStyle &&
      alertTipStyle == other.alertTipStyle &&
      alertImportantStyle == other.alertImportantStyle &&
      alertWarningStyle == other.alertWarningStyle &&
      alertCautionStyle == other.alertCautionStyle &&
      footnoteRefStyle == other.footnoteRefStyle &&
      footnoteDefinitionStyle == other.footnoteDefinitionStyle &&
      diffAddedStyle == other.diffAddedStyle &&
      diffRemovedStyle == other.diffRemovedStyle &&
      diffHunkStyle == other.diffHunkStyle &&
      diffMetaStyle == other.diffMetaStyle &&
      syntaxTheme == other.syntaxTheme &&
      bulletGlyph == other.bulletGlyph &&
      horizontalRuleChar == other.horizontalRuleChar &&
      taskCheckedGlyph == other.taskCheckedGlyph &&
      taskUncheckedGlyph == other.taskUncheckedGlyph;

  @override
  int get hashCode => Object.hashAll([
    name,
    brightness,
    background,
    textStyle,
    paragraphStyle,
    h1Style,
    h2Style,
    h3Style,
    h4Style,
    h5Style,
    h6Style,
    strongStyle,
    emphStyle,
    delStyle,
    codeStyle,
    codeBackgroundStyle,
    codeBlockStyle,
    codeBlockBackgroundStyle,
    blockQuoteStyle,
    blockQuoteBarStyle,
    linkStyle,
    linkTextStyle,
    listBulletStyle,
    listEnumerationStyle,
    horizontalRuleStyle,
    tableHeaderStyle,
    tableBorderStyle,
    tableCellStyle,
    imageStyle,
    imageTextStyle,
    taskCheckedStyle,
    taskUncheckedStyle,
    definitionListStyle,
    definitionTermStyle,
    definitionDescriptionStyle,
    alertNoteStyle,
    alertTipStyle,
    alertImportantStyle,
    alertWarningStyle,
    alertCautionStyle,
    footnoteRefStyle,
    footnoteDefinitionStyle,
    diffAddedStyle,
    diffRemovedStyle,
    diffHunkStyle,
    diffMetaStyle,
    syntaxTheme,
  ]);

  /// Builds a markdown theme from a small palette of base colors.
  ///
  /// Useful when the host app has its own color scheme (e.g. a terminal
  /// color scheme) that is not one of nocterm's built-in presets: pass the
  /// colors you care about and the rest is derived with the same rules as
  /// [fromTuiTheme]. Unspecified colors fall back to a sensible dark or
  /// light default based on [brightness].
  factory MarkdownTheme.fromPalette({
    String? name,
    Brightness brightness = Brightness.dark,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? primary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? error,
    Color? outline,
  }) {
    final light = brightness == Brightness.light;
    final bg =
        background ??
        (light ? const Color(0xFFFFFFFF) : const Color(0xFF1E1E2E));
    final onBg =
        onBackground ??
        (light ? const Color(0xFF1E1E2E) : const Color(0xFFCDD6F4));
    final surf =
        surface ?? (light ? const Color(0xFFF5F5F5) : const Color(0xFF313244));
    final onSurf = onSurface ?? onBg;
    final prim =
        primary ?? (light ? const Color(0xFF1E66F5) : const Color(0xFF89B4FA));
    final sec =
        secondary ??
        (light ? const Color(0xFF8839EF) : const Color(0xFFCBA6F7));
    final succ =
        success ?? (light ? const Color(0xFF40A02B) : const Color(0xFFA6E3A1));
    final warn =
        warning ?? (light ? const Color(0xFFDF8E1D) : const Color(0xFFF9E2AF));
    final err =
        error ?? (light ? const Color(0xFFD20F39) : const Color(0xFFF38BA8));
    final out =
        outline ?? (light ? const Color(0xFF9CA0B0) : const Color(0xFF6C7086));
    final data = TuiThemeData(
      brightness: brightness,
      background: bg,
      onBackground: onBg,
      surface: surf,
      onSurface: onSurf,
      primary: prim,
      onPrimary: bg,
      secondary: sec,
      onSecondary: bg,
      error: err,
      onError: bg,
      success: succ,
      onSuccess: bg,
      warning: warn,
      onWarning: bg,
      outline: out,
      outlineVariant: out,
      selectionColor: prim,
    );
    return MarkdownTheme.fromTuiTheme(data, name: name ?? 'palette');
  }

  /// Returns this theme with every color quantized to the xterm-256 palette.
  /// Suitable for terminals without truecolor support.
  MarkdownTheme quantizedToAnsi256() {
    MarkdownStyle? q(MarkdownStyle? style) =>
        style == null ? null : _quantizedStyle(style);
    return MarkdownTheme(
      name: name,
      brightness: brightness,
      background: background == null ? null : _xterm256(background!),
      textStyle: q(textStyle),
      paragraphStyle: q(paragraphStyle),
      h1Style: q(h1Style),
      h2Style: q(h2Style),
      h3Style: q(h3Style),
      h4Style: q(h4Style),
      h5Style: q(h5Style),
      h6Style: q(h6Style),
      strongStyle: q(strongStyle),
      emphStyle: q(emphStyle),
      delStyle: q(delStyle),
      codeStyle: q(codeStyle),
      codeBackgroundStyle: q(codeBackgroundStyle),
      codeBlockStyle: q(codeBlockStyle),
      codeBlockBackgroundStyle: q(codeBlockBackgroundStyle),
      blockQuoteStyle: q(blockQuoteStyle),
      blockQuoteBarStyle: q(blockQuoteBarStyle),
      linkStyle: q(linkStyle),
      linkTextStyle: q(linkTextStyle),
      listBulletStyle: q(listBulletStyle),
      listEnumerationStyle: q(listEnumerationStyle),
      horizontalRuleStyle: q(horizontalRuleStyle),
      tableHeaderStyle: q(tableHeaderStyle),
      tableBorderStyle: q(tableBorderStyle),
      tableCellStyle: q(tableCellStyle),
      imageStyle: q(imageStyle),
      imageTextStyle: q(imageTextStyle),
      taskCheckedStyle: q(taskCheckedStyle),
      taskUncheckedStyle: q(taskUncheckedStyle),
      definitionListStyle: q(definitionListStyle),
      definitionTermStyle: q(definitionTermStyle),
      definitionDescriptionStyle: q(definitionDescriptionStyle),
      alertNoteStyle: q(alertNoteStyle),
      alertTipStyle: q(alertTipStyle),
      alertImportantStyle: q(alertImportantStyle),
      alertWarningStyle: q(alertWarningStyle),
      alertCautionStyle: q(alertCautionStyle),
      footnoteRefStyle: q(footnoteRefStyle),
      footnoteDefinitionStyle: q(footnoteDefinitionStyle),
      diffAddedStyle: q(diffAddedStyle),
      diffRemovedStyle: q(diffRemovedStyle),
      diffHunkStyle: q(diffHunkStyle),
      diffMetaStyle: q(diffMetaStyle),
      syntaxTheme: syntaxTheme == null
          ? null
          : SyntaxTheme(
              keyword: q(syntaxTheme!.keyword),
              string: q(syntaxTheme!.string),
              number: q(syntaxTheme!.number),
              comment: q(syntaxTheme!.comment),
              function: q(syntaxTheme!.function),
              variable: q(syntaxTheme!.variable),
              type: q(syntaxTheme!.type),
              operator: q(syntaxTheme!.operator),
              punctuation: q(syntaxTheme!.punctuation),
              plain: q(syntaxTheme!.plain),
            ),
      bulletGlyph: bulletGlyph,
      horizontalRuleChar: horizontalRuleChar,
      taskCheckedGlyph: taskCheckedGlyph,
      taskUncheckedGlyph: taskUncheckedGlyph,
    );
  }

  /// Returns a copy whose every colour is blended toward the page background
  /// by [factor] (default 0.5), making the whole rendered markdown less
  /// prominent — useful for LLM "thinking" output that should not compete
  /// with the main answer. Emphasis flags, glyphs and the page background
  /// itself are preserved. Compose with [quantizedToAnsi256] as needed.
  MarkdownTheme dimmed({double factor = 0.5}) {
    final base =
        background ??
        (brightness == Brightness.dark
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF));
    MarkdownStyle? d(MarkdownStyle? s) => s?.dimmed(base, factor: factor);
    return copyWith(
      name: '$name (dimmed)',
      textStyle: d(textStyle),
      paragraphStyle: d(paragraphStyle),
      h1Style: d(h1Style),
      h2Style: d(h2Style),
      h3Style: d(h3Style),
      h4Style: d(h4Style),
      h5Style: d(h5Style),
      h6Style: d(h6Style),
      strongStyle: d(strongStyle),
      emphStyle: d(emphStyle),
      delStyle: d(delStyle),
      codeStyle: d(codeStyle),
      codeBackgroundStyle: d(codeBackgroundStyle),
      codeBlockStyle: d(codeBlockStyle),
      codeBlockBackgroundStyle: d(codeBlockBackgroundStyle),
      blockQuoteStyle: d(blockQuoteStyle),
      blockQuoteBarStyle: d(blockQuoteBarStyle),
      linkStyle: d(linkStyle),
      linkTextStyle: d(linkTextStyle),
      listBulletStyle: d(listBulletStyle),
      listEnumerationStyle: d(listEnumerationStyle),
      horizontalRuleStyle: d(horizontalRuleStyle),
      tableHeaderStyle: d(tableHeaderStyle),
      tableBorderStyle: d(tableBorderStyle),
      tableCellStyle: d(tableCellStyle),
      imageStyle: d(imageStyle),
      imageTextStyle: d(imageTextStyle),
      taskCheckedStyle: d(taskCheckedStyle),
      taskUncheckedStyle: d(taskUncheckedStyle),
      definitionListStyle: d(definitionListStyle),
      definitionTermStyle: d(definitionTermStyle),
      definitionDescriptionStyle: d(definitionDescriptionStyle),
      alertNoteStyle: d(alertNoteStyle),
      alertTipStyle: d(alertTipStyle),
      alertImportantStyle: d(alertImportantStyle),
      alertWarningStyle: d(alertWarningStyle),
      alertCautionStyle: d(alertCautionStyle),
      footnoteRefStyle: d(footnoteRefStyle),
      footnoteDefinitionStyle: d(footnoteDefinitionStyle),
      diffAddedStyle: d(diffAddedStyle),
      diffRemovedStyle: d(diffRemovedStyle),
      diffHunkStyle: d(diffHunkStyle),
      diffMetaStyle: d(diffMetaStyle),
      syntaxTheme: syntaxTheme?.dimmed(base, factor: factor),
    );
  }
}

/// Converts a color to the nearest xterm-256 ANSI palette color.
///
/// The 256-color palette consists of:
/// - 16 base colors (0-15)
/// - A 6x6x6 color cube (16-231) with levels 0, 95, 135, 175, 215, 255
/// - A grayscale ramp (232-255) from #080808 to #e8e8e8

/// A dark/light theme pair resolved by terminal brightness.
class AdaptiveMarkdownTheme {
  const AdaptiveMarkdownTheme({required this.dark, required this.light});

  final MarkdownTheme dark;
  final MarkdownTheme light;

  /// Resolves the theme for the given [brightness].
  MarkdownTheme resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

Color _xterm256(Color color) {
  const cube = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
  int nearestCube(int c) {
    var best = cube.first;
    var bestDiff = 255;
    for (final level in cube) {
      final diff = (c - level).abs();
      if (diff < bestDiff) {
        best = level;
        bestDiff = diff;
      }
    }
    return best;
  }

  final r = nearestCube(color.red);
  final g = nearestCube(color.green);
  final b = nearestCube(color.blue);

  final gray = (color.red + color.green + color.blue) ~/ 3;
  final grayIndex = ((gray - 8) / 10).round().clamp(0, 23);
  final grayColor = Color.fromRGB(
    8 + 10 * grayIndex,
    8 + 10 * grayIndex,
    8 + 10 * grayIndex,
  );

  final cubeDistance =
      (r - color.red).abs() + (g - color.green).abs() + (b - color.blue).abs();
  final grayDistance =
      (grayColor.red - color.red).abs() +
      (grayColor.green - color.green).abs() +
      (grayColor.blue - color.blue).abs();

  return grayDistance < cubeDistance ? grayColor : Color.fromRGB(r, g, b);
}

MarkdownStyle _quantizedStyle(MarkdownStyle style) {
  return MarkdownStyle(
    color: style.color == null ? null : _xterm256(style.color!),
    background: style.background == null ? null : _xterm256(style.background!),
    bold: style.bold,
    italic: style.italic,
    underline: style.underline,
    strikethrough: style.strikethrough,
    prefix: style.prefix,
    suffix: style.suffix,
  );
}

Color _scaled(Color color, double factor) {
  int channel(int v) => (v * factor).round().clamp(0, 255);
  return Color.fromRGB(
    channel(color.red),
    channel(color.green),
    channel(color.blue),
  );
}

Color blendColors(Color a, Color b, double t) {
  int channel(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
  return Color.fromRGB(
    channel(a.red, b.red),
    channel(a.green, b.green),
    channel(a.blue, b.blue),
  );
}

String _hex(Color color) {
  String channel(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${channel(color.red)}${channel(color.green)}${channel(color.blue)}';
}

Color? _parseHex(String? value) {
  if (value == null) return null;
  var hex = value.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
