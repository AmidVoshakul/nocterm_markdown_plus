import 'package:nocterm/nocterm.dart';

import 'markdown_theme.dart';

/// Raw palette of a theme family — the data every preset is derived from.
class _Palette {
  const _Palette({
    required this.fg,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.strong,
    required this.emph,
    required this.green,
    required this.blue,
    required this.cyan,
    required this.red,
    required this.codeBg,
  });

  final int fg;
  final int muted;
  final int accent;
  final int accent2;
  final int strong;
  final int emph;
  final int green;
  final int blue;
  final int cyan;
  final int red;
  final int codeBg;
}

Color _c(int hex) => Color(0xFF000000 | hex);

/// Blends two colors — used to lift dim roles (syntax comments) to AA
/// contrast on the code background while keeping them visually recessive.
Color _blend(Color a, Color b, double t) {
  int ch(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
  return Color.fromRGB(
    ch(a.red, b.red),
    ch(a.green, b.green),
    ch(a.blue, b.blue),
  );
}

MarkdownStyle _s(
  Color color, {
  bool bold = false,
  bool italic = false,
  bool underline = false,
}) {
  return MarkdownStyle(
    color: color,
    bold: bold,
    italic: italic,
    underline: underline,
  );
}

/// Maps a raw palette onto the full [MarkdownTheme] slot set.
MarkdownTheme _theme(String name, Brightness brightness, _Palette raw) {
  final fg = _c(raw.fg);
  final muted = _c(raw.muted);
  final accent = _c(raw.accent);
  final accent2 = _c(raw.accent2);
  final strong = _c(raw.strong);
  final emph = _c(raw.emph);
  final green = _c(raw.green);
  final blue = _c(raw.blue);
  final cyan = _c(raw.cyan);
  final red_ = _c(raw.red);
  final codeBg = _c(raw.codeBg);

  final syntax = SyntaxTheme(
    keyword: _s(accent),
    string: _s(green),
    number: _s(emph),
    comment: _s(_blend(muted, fg, 0.68), italic: true),
    function: _s(accent2),
    variable: _s(fg),
    type: _s(cyan),
    operator: _s(accent2),
    punctuation: _s(muted),
    plain: _s(fg),
  );
  return MarkdownTheme(
    name: name,
    brightness: brightness,
    background: codeBg,
    textStyle: _s(fg),
    h1Style: _s(accent, bold: true),
    h2Style: _s(accent, bold: true),
    h3Style: _s(accent2, bold: true),
    h4Style: _s(fg, bold: true),
    h5Style: _s(fg, bold: true),
    h6Style: _s(fg, bold: true),
    strongStyle: _s(strong, bold: true),
    emphStyle: _s(emph, italic: true),
    delStyle: _s(muted).copyWith(strikethrough: true),
    codeStyle: _s(green).copyWith(prefix: ' ', suffix: ' '),
    codeBackgroundStyle: MarkdownStyle(background: codeBg),
    codeBlockStyle: _s(fg),
    codeBlockBackgroundStyle: MarkdownStyle(background: codeBg),
    blockQuoteStyle: _s(fg, italic: true),
    blockQuoteBarStyle: _s(accent2).copyWith(prefix: '│ '),
    linkStyle: _s(blue, underline: true),
    linkTextStyle: _s(cyan),
    listBulletStyle: _s(accent2).copyWith(prefix: '• '),
    listEnumerationStyle: _s(cyan),
    horizontalRuleStyle: _s(muted),
    tableHeaderStyle: _s(accent, bold: true),
    tableBorderStyle: _s(muted),
    tableCellStyle: _s(fg),
    imageStyle: _s(cyan, italic: true),
    imageTextStyle: _s(muted),
    taskCheckedStyle: MarkdownStyle(color: green, prefix: '☑ '),
    taskUncheckedStyle: MarkdownStyle(color: muted, prefix: '☐ '),
    definitionListStyle: _s(fg),
    definitionTermStyle: _s(accent, bold: true),
    definitionDescriptionStyle: _s(fg),
    alertNoteStyle: _s(blue).copyWith(prefix: 'ℹ '),
    alertTipStyle: _s(green).copyWith(prefix: '💡 '),
    alertImportantStyle: _s(accent2).copyWith(prefix: '❗ '),
    alertWarningStyle: _s(emph).copyWith(prefix: '⚠ '),
    alertCautionStyle: _s(red_).copyWith(prefix: '🔥 '),
    footnoteRefStyle: _s(cyan).copyWith(prefix: '[', suffix: ']'),
    footnoteDefinitionStyle: _s(muted),
    diffAddedStyle: _s(green),
    diffRemovedStyle: _s(red_),
    diffHunkStyle: _s(emph),
    diffMetaStyle: _s(muted),
    syntaxTheme: syntax,
  );
}

/// Built-in markdown themes.
///
/// Every preset is a canonical singleton derived from a curated palette and
/// mapped onto the full [MarkdownTheme] slot set.
abstract final class MarkdownThemes {
  static const _dark = Brightness.dark;

  /// Catppuccin Mocha — warm, cozy pastel dark theme.
  static final MarkdownTheme catppuccinMocha = _theme(
    'catppuccin-mocha',
    _dark,
    const _Palette(
      fg: 0xcdd6f4,
      red: 0xf38ba8,
      muted: 0x6c7086,
      accent: 0xcba6f7,
      accent2: 0x74c7ec,
      strong: 0xfab387,
      emph: 0xf9e2af,
      green: 0xa6e3a1,
      blue: 0x89b4fa,
      cyan: 0x94e2d5,
      codeBg: 0x181825,
    ),
  );

  /// Nord — arctic, north-bluish palette.
  static final MarkdownTheme nord = _theme(
    'nord',
    _dark,
    const _Palette(
      fg: 0xd8dee9,
      red: 0xbf616a,
      muted: 0x4c566a,
      accent: 0x88c0d0,
      accent2: 0x81a1c1,
      strong: 0xd08770,
      emph: 0xebcb8b,
      green: 0xa3be8c,
      blue: 0x81a1c1,
      cyan: 0x8fbcbb,
      codeBg: 0x292e39,
    ),
  );

  /// Dracula — vibrant dark theme.
  static final MarkdownTheme dracula = _theme(
    'dracula',
    _dark,
    const _Palette(
      fg: 0xf8f8f2,
      red: 0xff5555,
      muted: 0x6272a4,
      accent: 0xbd93f9,
      accent2: 0xff79c6,
      strong: 0xffb86c,
      emph: 0xf1fa8c,
      green: 0x50fa7b,
      blue: 0x8be9fd,
      cyan: 0xff79c6,
      codeBg: 0x21222c,
    ),
  );

  /// Tokyo Night — clean dark theme inspired by Tokyo city lights.
  static final MarkdownTheme tokyoNight = _theme(
    'tokyo-night',
    _dark,
    const _Palette(
      fg: 0xc0caf5,
      red: 0xf7768e,
      muted: 0x565f89,
      accent: 0x7aa2f7,
      accent2: 0xbb9af7,
      strong: 0xff9e64,
      emph: 0xe0af68,
      green: 0x9ece6a,
      blue: 0x7aa2f7,
      cyan: 0x7dcfff,
      codeBg: 0x16161e,
    ),
  );

  /// One Dark — Atom's iconic dark theme.
  static final MarkdownTheme oneDark = _theme(
    'one-dark',
    _dark,
    const _Palette(
      fg: 0xabb2bf,
      red: 0xe06c75,
      muted: 0x5c6370,
      accent: 0xc678dd,
      accent2: 0x61afef,
      strong: 0xd19a66,
      emph: 0xe5c07b,
      green: 0x98c379,
      blue: 0x61afef,
      cyan: 0x56b6c2,
      codeBg: 0x21252b,
    ),
  );

  /// Gruvbox Dark — retro groove theme.
  static final MarkdownTheme gruvboxDark = _theme(
    'gruvbox-dark',
    _dark,
    const _Palette(
      fg: 0xebdbb2,
      red: 0xfb4934,
      muted: 0x928374,
      accent: 0x8ec07c,
      accent2: 0x83a598,
      strong: 0xfe8019,
      emph: 0xfabd2f,
      green: 0xb8bb26,
      blue: 0x83a598,
      cyan: 0x8ec07c,
      codeBg: 0x1d2021,
    ),
  );

  /// Monokai — classic Sublime Text theme.
  static final MarkdownTheme monokai = _theme(
    'monokai',
    _dark,
    const _Palette(
      fg: 0xf8f8f2,
      red: 0xf92672,
      muted: 0x75715e,
      accent: 0xff5793,
      accent2: 0xc4a2ff,
      strong: 0xfd971f,
      emph: 0xf4bf75,
      green: 0xa6e22e,
      blue: 0x66d9ef,
      cyan: 0xa1efe4,
      codeBg: 0x1e1f1c,
    ),
  );

  /// GitHub Dark — GitHub's dark interface theme.
  static final MarkdownTheme githubDark = _theme(
    'github-dark',
    _dark,
    const _Palette(
      fg: 0xc9d1d9,
      red: 0xf85149,
      muted: 0x8b949e,
      accent: 0x58a6ff,
      accent2: 0xbc8cff,
      strong: 0xdb6d28,
      emph: 0xd29922,
      green: 0x3fb950,
      blue: 0x58a6ff,
      cyan: 0x39c5cf,
      codeBg: 0x010409,
    ),
  );

  /// Ayu Dark — minimalist dark theme with vivid accents.
  static final MarkdownTheme ayuDark = _theme(
    'ayu-dark',
    _dark,
    const _Palette(
      fg: 0xbfbdb6,
      red: 0xf07178,
      muted: 0x565b66,
      accent: 0xff8f40,
      accent2: 0x59c2ff,
      strong: 0xf29668,
      emph: 0xe6b450,
      green: 0xaad94c,
      blue: 0x59c2ff,
      cyan: 0x39bae6,
      codeBg: 0x0d1017,
    ),
  );

  /// Solarized Dark — Ethan Schoonover's precision color scheme.
  static final MarkdownTheme solarizedDark = _theme(
    'solarized-dark',
    _dark,
    const _Palette(
      fg: 0x839496,
      red: 0xdc322f,
      muted: 0x586e75,
      accent: 0x268bd2,
      accent2: 0x6c71c4,
      strong: 0xcb4b16,
      emph: 0xb58900,
      green: 0x859900,
      blue: 0x268bd2,
      cyan: 0x2aa198,
      codeBg: 0x00212b,
    ),
  );

  /// Matrix — luminous terminal green on deep black.
  static final MarkdownTheme matrix = _theme(
    'matrix',
    _dark,
    const _Palette(
      fg: 0x33ff66,
      red: 0xff5c5c,
      muted: 0x4a9a5e,
      accent: 0x5cff8a,
      accent2: 0x2ee6a8,
      strong: 0xb8e986,
      emph: 0xa8ffb0,
      green: 0x5cff87,
      blue: 0x4dd9a8,
      cyan: 0x66ffd9,
      codeBg: 0x080a08,
    ),
  );

  /// nocterm's own default dark theme, expressed as a markdown theme.
  static final MarkdownTheme nocterm = MarkdownTheme.fromTuiTheme(
    TuiThemeData.dark,
    name: 'nocterm',
  );

  // ===== Light themes =====

  /// Catppuccin Latte — light companion of Mocha.
  static final MarkdownTheme catppuccinLatte = _theme(
    'catppuccin-latte',
    Brightness.light,
    const _Palette(
      fg: 0x4c4f69,
      red: 0xd20f39,
      muted: 0x6c6f85,
      accent: 0x5c19b0,
      accent2: 0x177f96,
      strong: 0xc74e08,
      emph: 0xa9720f,
      green: 0x2f7d21,
      blue: 0x1a5cc4,
      cyan: 0x117a72,
      codeBg: 0xe6e9ef,
    ),
  );

  /// Solarized Light — light companion of Solarized Dark.
  static final MarkdownTheme solarizedLight = _theme(
    'solarized-light',
    Brightness.light,
    const _Palette(
      fg: 0x52676f,
      red: 0xb0201d,
      muted: 0x7a8a8d,
      accent: 0x1a5fa8,
      accent2: 0x4f56b8,
      strong: 0xb5410f,
      emph: 0x7d6800,
      green: 0x647300,
      blue: 0x1a5fa8,
      cyan: 0x1e7d75,
      codeBg: 0xfdf6e3,
    ),
  );

  /// GitHub Light — light companion of GitHub Dark.
  static final MarkdownTheme githubLight = _theme(
    'github-light',
    Brightness.light,
    const _Palette(
      fg: 0x1f2328,
      red: 0xcf222e,
      muted: 0x59636e,
      accent: 0x063d80,
      accent2: 0x6b3bc4,
      strong: 0x9a3f00,
      emph: 0x7d5500,
      green: 0x146a2b,
      blue: 0x063d80,
      cyan: 0x14636a,
      codeBg: 0xebeef2,
    ),
  );

  /// One Light — Atom's light theme.
  static final MarkdownTheme oneLight = _theme(
    'one-light',
    Brightness.light,
    const _Palette(
      fg: 0x383a42,
      red: 0xe45649,
      muted: 0x696c77,
      accent: 0xa626a4,
      accent2: 0x4078f2,
      strong: 0xc18401,
      emph: 0x986801,
      green: 0x50a14f,
      blue: 0x2f66d4,
      cyan: 0x0184bc,
      codeBg: 0xf0f0f0,
    ),
  );

  /// Ayu Light — light companion of Ayu Dark.
  static final MarkdownTheme ayuLight = _theme(
    'ayu-light',
    Brightness.light,
    const _Palette(
      fg: 0x4d5661,
      red: 0xc62d2d,
      muted: 0x8a9199,
      accent: 0xa8480f,
      accent2: 0x1f6fd0,
      strong: 0xb54f14,
      emph: 0x9a6b12,
      green: 0x5f8400,
      blue: 0x1a63b8,
      cyan: 0x1a7ba0,
      codeBg: 0xf0f1f2,
    ),
  );

  /// Colorless fallback for terminals without color support: no colors,
  /// markers rendered as literal glyphs (`**bold**`, `` `code` ``).
  static final MarkdownTheme ascii = MarkdownTheme(
    name: 'ascii',
    brightness: Brightness.dark,
    textStyle: MarkdownStyle.empty,
    h1Style: const MarkdownStyle(prefix: '# '),
    h2Style: const MarkdownStyle(prefix: '## '),
    h3Style: const MarkdownStyle(prefix: '### '),
    h4Style: const MarkdownStyle(prefix: '#### '),
    h5Style: const MarkdownStyle(prefix: '##### '),
    h6Style: const MarkdownStyle(prefix: '###### '),
    strongStyle: const MarkdownStyle(prefix: '**', suffix: '**'),
    emphStyle: const MarkdownStyle(prefix: '*', suffix: '*'),
    delStyle: const MarkdownStyle(prefix: '~~', suffix: '~~'),
    codeStyle: const MarkdownStyle(prefix: '`', suffix: '`'),
    blockQuoteStyle: MarkdownStyle.empty,
    blockQuoteBarStyle: const MarkdownStyle(prefix: '> '),
    linkStyle: MarkdownStyle.empty,
    listBulletStyle: const MarkdownStyle(prefix: '* '),
    horizontalRuleStyle: MarkdownStyle.empty,
    tableHeaderStyle: MarkdownStyle.empty,
    tableCellStyle: MarkdownStyle.empty,
    imageStyle: MarkdownStyle.empty,
    imageTextStyle: MarkdownStyle.empty,
    taskCheckedStyle: const MarkdownStyle(prefix: '[x] '),
    taskUncheckedStyle: const MarkdownStyle(prefix: '[ ] '),
    definitionListStyle: MarkdownStyle.empty,
    definitionTermStyle: MarkdownStyle.empty,
    definitionDescriptionStyle: MarkdownStyle.empty,
    alertNoteStyle: const MarkdownStyle(prefix: 'NOTE '),
    alertTipStyle: const MarkdownStyle(prefix: 'TIP '),
    alertImportantStyle: const MarkdownStyle(prefix: 'IMPORTANT '),
    alertWarningStyle: const MarkdownStyle(prefix: 'WARNING '),
    alertCautionStyle: const MarkdownStyle(prefix: 'CAUTION '),
    bulletGlyph: '* ',
    horizontalRuleChar: '-',
    taskCheckedGlyph: '[x] ',
    taskUncheckedGlyph: '[ ] ',
  );

  /// All built-in dark presets in gallery order.
  static final List<MarkdownTheme> darkGallery = [
    catppuccinMocha,
    nord,
    dracula,
    tokyoNight,
    oneDark,
    gruvboxDark,
    monokai,
    githubDark,
    ayuDark,
    solarizedDark,
    matrix,
    nocterm,
  ];

  /// All built-in light presets in gallery order.
  static final List<MarkdownTheme> lightGallery = [
    catppuccinLatte,
    solarizedLight,
    githubLight,
    oneLight,
    ayuLight,
    MarkdownTheme.fromTuiTheme(TuiThemeData.light, name: 'nocterm-light'),
  ];

  /// Every built-in preset (dark + light) in gallery order.
  static final List<MarkdownTheme> gallery = [
    ...darkGallery,
    ...lightGallery,
    ascii,
  ];

  /// Dark/light pairs for families that ship both, resolved by terminal
  /// brightness via [AdaptiveMarkdownTheme].
  static final List<AdaptiveMarkdownTheme> adaptive = [
    AdaptiveMarkdownTheme(dark: catppuccinMocha, light: catppuccinLatte),
    AdaptiveMarkdownTheme(dark: solarizedDark, light: solarizedLight),
    AdaptiveMarkdownTheme(dark: githubDark, light: githubLight),
    AdaptiveMarkdownTheme(dark: oneDark, light: oneLight),
    AdaptiveMarkdownTheme(dark: ayuDark, light: ayuLight),
  ];
}
