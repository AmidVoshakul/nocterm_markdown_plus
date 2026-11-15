import 'dart:convert';

import 'package:markdown/markdown.dart' as md;
import 'package:nocterm/nocterm.dart' hide isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

void main() {
  group('dimmed', () {
    test('blends foreground toward background', () {
      const style = MarkdownStyle.all(Color(0xFFFFFFFF));
      final dim = style.dimmed(const Color(0xFF000000), factor: 0.5);
      expect(dim.color, const Color(0xFF808080));
      expect(dim.bold, isFalse);
    });

    test('theme.dimmed preserves background and changes name', () {
      final t = MarkdownThemes.catppuccinMocha;
      final d = t.dimmed(factor: 0.5);
      expect(d.background, t.background);
      expect(d.name, contains('dimmed'));
      expect(d.textStyle!.color, isNot(t.textStyle!.color));
    });
  });

  group('MarkdownStyle', () {
    test('copyWith overrides selectively', () {
      const style = MarkdownStyle.all(Color(0xFF112233));
      final bold = style.copyWith(bold: true);
      expect(bold.color, style.color);
      expect(bold.bold, isTrue);
      expect(style.bold, isFalse);
    });

    test('toJson/fromJson round trip', () {
      const style = MarkdownStyle(
        color: Color(0xFFabcdef),
        background: Color(0xFF123456),
        bold: true,
        italic: true,
        underline: true,
        strikethrough: true,
      );
      final restored = MarkdownStyle.fromJson(style.toJson());
      expect(restored, style);
    });
  });

  group('presets', () {
    test('every preset fills all style slots', () {
      for (final theme in MarkdownThemes.gallery.where(
        (t) => t.name != 'ascii',
      )) {
        expect(theme.textStyle, isNotNull, reason: '${theme.name} text');
        expect(theme.h1Style, isNotNull, reason: '${theme.name} h1');
        expect(theme.h2Style, isNotNull, reason: '${theme.name} h2');
        expect(theme.h3Style, isNotNull, reason: '${theme.name} h3');
        expect(theme.h4Style, isNotNull, reason: '${theme.name} h4');
        expect(theme.h5Style, isNotNull, reason: '${theme.name} h5');
        expect(theme.h6Style, isNotNull, reason: '${theme.name} h6');
        expect(theme.strongStyle, isNotNull, reason: '${theme.name} strong');
        expect(theme.emphStyle, isNotNull, reason: '${theme.name} emph');
        expect(theme.delStyle, isNotNull, reason: '${theme.name} del');
        expect(theme.codeStyle, isNotNull, reason: '${theme.name} code');
        expect(
          theme.codeBackgroundStyle,
          isNotNull,
          reason: '${theme.name} codeBackground',
        );
        expect(
          theme.codeBlockStyle,
          isNotNull,
          reason: '${theme.name} codeBlock',
        );
        expect(
          theme.codeBlockBackgroundStyle,
          isNotNull,
          reason: '${theme.name} codeBlockBackground',
        );
        expect(
          theme.blockQuoteStyle,
          isNotNull,
          reason: '${theme.name} blockQuote',
        );
        expect(
          theme.blockQuoteBarStyle,
          isNotNull,
          reason: '${theme.name} blockQuoteBar',
        );
        expect(theme.linkStyle, isNotNull, reason: '${theme.name} link');
        expect(
          theme.linkTextStyle,
          isNotNull,
          reason: '${theme.name} linkText',
        );
        expect(
          theme.listBulletStyle,
          isNotNull,
          reason: '${theme.name} listBullet',
        );
        expect(
          theme.listEnumerationStyle,
          isNotNull,
          reason: '${theme.name} listEnumeration',
        );
        expect(
          theme.horizontalRuleStyle,
          isNotNull,
          reason: '${theme.name} horizontalRule',
        );
        expect(
          theme.tableHeaderStyle,
          isNotNull,
          reason: '${theme.name} tableHeader',
        );
        expect(
          theme.tableBorderStyle,
          isNotNull,
          reason: '${theme.name} tableBorder',
        );
        expect(
          theme.tableCellStyle,
          isNotNull,
          reason: '${theme.name} tableCell',
        );
        expect(theme.imageStyle, isNotNull, reason: '${theme.name} image');
        expect(theme.syntaxTheme, isNotNull, reason: '${theme.name} syntax');
      }
    });

    test('every preset has a background color', () {
      // The ascii fallback is colorless on purpose, background included.
      for (final theme in MarkdownThemes.gallery.where(
        (t) => t.name != 'ascii',
      )) {
        expect(theme.background, isNotNull, reason: '${theme.name} background');
      }
    });

    test('background survives JSON round trip', () {
      final theme = MarkdownThemes.githubDark;
      final restored = MarkdownTheme.fromJson(
        jsonDecode(jsonEncode(theme.toJson())),
      );
      expect(restored.background, theme.background);
      expect(restored, theme);
    });

    test('gallery covers dark and light families', () {
      expect(MarkdownThemes.darkGallery.length, 12);
      expect(MarkdownThemes.lightGallery.length, 6);
      expect(MarkdownThemes.gallery.length, 19);
      expect(MarkdownThemes.adaptive.length, 5);
      for (final pair in MarkdownThemes.adaptive) {
        expect(pair.dark.brightness, Brightness.dark);
        expect(pair.light.brightness, Brightness.light);
      }
    });

    test('presets are singletons (identical)', () {
      expect(identical(MarkdownThemes.nord, MarkdownThemes.nord), isTrue);
    });
  });

  group('MarkdownTheme JSON', () {
    test('round trips a preset', () {
      final theme = MarkdownThemes.catppuccinMocha;
      final json =
          jsonDecode(jsonEncode(theme.toJson())) as Map<String, dynamic>;
      final restored = MarkdownTheme.fromJson(json);
      expect(restored.name, theme.name);
      expect(restored.textStyle, theme.textStyle);
      expect(restored.h1Style, theme.h1Style);
      expect(restored.syntaxTheme, theme.syntaxTheme);
      expect(restored, theme);
    });
  });

  group('fromTuiTheme', () {
    test('maps all nocterm core themes', () {
      for (final data in [
        TuiThemeData.dark,
        TuiThemeData.light,
        TuiThemeData.nord,
        TuiThemeData.dracula,
        TuiThemeData.catppuccinMocha,
        TuiThemeData.gruvboxDark,
      ]) {
        final theme = MarkdownTheme.fromTuiTheme(data);
        expect(theme.brightness, data.brightness);
        expect(theme.textStyle, isNotNull);
        expect(theme.h1Style, isNotNull);
      }
    });
  });

  group('adaptive', () {
    test('resolves by brightness', () {
      const adaptive = AdaptiveMarkdownTheme(
        dark: MarkdownTheme(name: 'd', brightness: Brightness.dark),
        light: MarkdownTheme(name: 'l', brightness: Brightness.light),
      );
      expect(adaptive.resolve(Brightness.dark).name, 'd');
      expect(adaptive.resolve(Brightness.light).name, 'l');
    });
  });

  group('quantized', () {
    test('quantizedToAnsi256 runs over a preset', () {
      final q = MarkdownThemes.catppuccinMocha.quantizedToAnsi256();
      expect(q.name, MarkdownThemes.catppuccinMocha.name);
      expect(q.textStyle, isNotNull);
    });
  });

  group('SyntaxTheme', () {
    test('toJson/fromJson round trip', () {
      const syntax = SyntaxTheme(
        keyword: MarkdownStyle.all(Color(0xFF0000FF)),
        string: MarkdownStyle(color: Color(0xFF00FF00), bold: true),
      );
      final restored = SyntaxTheme.fromJson(syntax.toJson());
      expect(restored, syntax);
    });
  });

  group('PlainHighlighter', () {
    test('emits one plain token per line', () {
      const highlighter = PlainHighlighter();
      final lines = highlighter.highlight('a\nb');
      expect(lines.length, 2);
      expect(lines[0].single.type, CodeTokenType.plain);
      expect(lines[1].single.text, 'b');
    });
  });

  group('styleForToken', () {
    test('maps token types to syntax slots with fallbacks', () {
      const syntax = SyntaxTheme(
        keyword: MarkdownStyle.all(Color(0xFF0000FF)),
        plain: MarkdownStyle.all(Color(0xFFFFFFFF)),
      );
      expect(
        styleForToken(syntax, CodeTokenType.keyword)?.color,
        const Color(0xFF0000FF),
      );
      expect(
        styleForToken(syntax, CodeTokenType.string),
        syntax.plain,
      ); // fallback
      expect(styleForToken(null, CodeTokenType.keyword), isNull);
    });
  });

  group('light theme body text', () {
    // Regression: paragraph spans must carry an explicit color, otherwise the
    // terminal default (white) is used — invisible on light themes.
    test('painted paragraph text is dark on light themes', () {
      for (final theme in MarkdownThemes.lightGallery) {
        final doc = md.Document(
          extensionSet: md.ExtensionSet.gitHubWeb,
          encodeHtml: false,
        );
        final spans = MarkdownPlusVisitor(theme)
            .visitNodes(doc.parse('Body text.'));
        final root = TextSpan(children: spans);
        final segments = root.toStyledSegments();
        final textSegments = segments
            .where((s) => s.text.trim().isNotEmpty)
            .toList();
        expect(textSegments, isNotEmpty, reason: '${theme.name} has no text');
        for (final segment in textSegments) {
          final color = segment.style?.color;
          expect(color, isNotNull, reason: '${theme.name} body color');
          final brightness = (color!.red + color.green + color.blue) / 3;
          expect(
            brightness,
            lessThan(128),
            reason: '${theme.name} body text must be dark',
          );
        }
      }
    });

    // Regression: bare text nodes inside <li> carry no style of their own,
    // so the list-item wrapper must provide the base text color; otherwise the
    // terminal default (white) is used — invisible on light themes.
    test('painted list item text is dark on light themes', () {
      const source =
          '1. plain item\n2. second item\n\n- bullet item\n\n'
          '- [x] done task\n- [ ] open task';
      for (final theme in MarkdownThemes.lightGallery) {
        final doc = md.Document(
          extensionSet: md.ExtensionSet.gitHubWeb,
          encodeHtml: false,
        );
        final spans = MarkdownPlusVisitor(theme).visitNodes(doc.parse(source));
        final root = TextSpan(children: spans);
        final rendered = root.toPlainText();
        for (final needle in ['plain item', 'bullet item', 'done task']) {
          expect(
            rendered,
            contains(needle),
            reason: '${theme.name} list rendering changed',
          );
        }
        final textSegments = root
            .toStyledSegments()
            .where((s) => s.text.trim().isNotEmpty)
            .toList();
        expect(
          textSegments,
          isNotEmpty,
          reason: '${theme.name} list has no text segments',
        );
        for (final segment in textSegments) {
          final color = segment.style?.color;
          expect(
            color,
            isNotNull,
            reason: '${theme.name} list segment "${segment.text}" has no color',
          );
          final brightness = (color!.red + color.green + color.blue) / 3;
          expect(
            brightness,
            lessThan(160),
            reason: '${theme.name} list segment "${segment.text}" too light',
          );
        }
      }
    });

    // The list-item wrapper color must not bleed into inline markup: bold text
    // keeps its own strong color rather than the body text color.
    test('inline markup keeps its own color inside list items', () {
      const source = '- **bold** plain';
      for (final theme in MarkdownThemes.lightGallery) {
        final doc = md.Document(
          extensionSet: md.ExtensionSet.gitHubWeb,
          encodeHtml: false,
        );
        final spans = MarkdownPlusVisitor(theme).visitNodes(doc.parse(source));
        final root = TextSpan(children: spans);
        final rendered = root.toPlainText();
        expect(rendered, contains('bold plain'), reason: theme.name);
        final bold = root.toStyledSegments().firstWhere(
          (s) => s.text.contains('bold'),
        );
        final strongColor = theme.strongStyle?.color;
        expect(strongColor, isNotNull, reason: '${theme.name} strong style');
        expect(
          bold.style?.color,
          strongColor,
          reason: '${theme.name} bold lost its strong color',
        );
      }
    });
  });

  group('theme copying', () {
    // Regression: copyWith dropped the page background, so the README's
    // `MarkdownThemes.dracula.copyWith(...)` recipe rendered without the
    // themed backdrop.
    test('copyWith keeps the page background', () {
      final original = MarkdownThemes.dracula;
      final copy = original.copyWith(
        h1Style: const MarkdownStyle.all(Color(0xFFFF79C6)),
      );
      expect(copy.background, same(original.background));
      expect(
        copy.copyWith(background: const Color(0xFF112233)).background,
        const Color(0xFF112233),
      );
    });

    // The background is painted, so it must also take part in ==/hashCode —
    // otherwise two themes differing only in backdrop compare equal.
    test('background participates in equality', () {
      final a = MarkdownThemes.dracula;
      final b = a.copyWith(background: const Color(0xFF101010));
      expect(b, isNot(a));
      expect(b.copyWith(background: a.background), a);
    });
  });
}
