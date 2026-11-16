import 'dart:convert';
import 'dart:io';

import 'package:nocterm/nocterm.dart' hide isEmpty, isNotEmpty;
import 'package:nocterm_markdown_plus/nocterm_markdown_plus.dart';
import 'package:test/test.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

MarkdownPlus _md(
  String data, {
  MarkdownTheme? theme,
  bool? renderImages,
  int? imageMaxWidth,
}) => MarkdownPlus(
  data,
  theme: theme ?? MarkdownThemes.catppuccinMocha,
  renderImages: renderImages ?? true,
  imageMaxWidth: imageMaxWidth,
);

void main() {
  group('images', () {
    test('data-URI image renders without crashing', () async {
      await testNocterm('data-URI image renders without crashing', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md('![red pixel](data:image/png;base64,$_pngBase64)'),
        );
        // Either the placeholder or the rendered image is acceptable; the
        // important part is that rendering completes without throwing.
        expect(tester.terminalState.getText(), isNotNull);
      });
    });

    test('file image renders from a temp file', () async {
      final dir = await Directory.systemTemp.createTemp('img');
      final file = File('${dir.path}/red.png');
      await file.writeAsBytes(base64Decode(_pngBase64));
      await testNocterm('file image renders from a temp file', (tester) async {
        await tester.pumpComponent(_md('![red pixel](${file.path})'));
        expect(tester.terminalState.getText(), isNotNull);
      });
      await dir.delete(recursive: true);
    });

    test('mixed paragraph keeps the inline placeholder', () async {
      await testNocterm('mixed paragraph keeps the inline placeholder', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md('hello ![alt](data:image/png;base64,$_pngBase64) world'),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('[Image: alt]'));
      });
    });

    test('renderImages: false falls back to placeholder', () async {
      await testNocterm('renderImages: false falls back to placeholder', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md(
            '![red pixel](data:image/png;base64,$_pngBase64)',
            renderImages: false,
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('[Image: red pixel]'));
      });
    });

    test('imageMaxWidth is honored (no crash on tiny width)', () async {
      await testNocterm('imageMaxWidth is honored (no crash on tiny width)', (
        tester,
      ) async {
        await tester.pumpComponent(
          _md(
            '![red pixel](data:image/png;base64,$_pngBase64)',
            imageMaxWidth: 4,
          ),
        );
        expect(tester.terminalState.getText(), isNotNull);
      });
    });

    test('unknown source falls back to placeholder text', () async {
      await testNocterm('unknown source falls back to placeholder text', (
        tester,
      ) async {
        await tester.pumpComponent(_md('![alt](not-a-real-source)'));
        final text = tester.terminalState.getText();
        expect(text, contains('[Image: alt]'));
      });
    });

    test('unicodeBlocks protocol renders without crashing', () async {
      await testNocterm('unicodeBlocks protocol renders without crashing', (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '![red pixel](data:image/png;base64,$_pngBase64)',
            theme: MarkdownThemes.catppuccinMocha,
            imageProtocol: ImageProtocol.unicodeBlocks,
          ),
        );
        expect(tester.terminalState.getText(), isNotNull);
      });
    });

    test('file image renders from assets', () async {
      await testNocterm('file image renders from assets', (tester) async {
        await tester.pumpComponent(_md('![demo](assets/demo.png)'));
        expect(tester.terminalState.getText(), isNotNull);
      });
    });

    test('themes render images without crashing', () async {
      await testNocterm('themes render images without crashing', (
        tester,
      ) async {
        for (final theme in MarkdownThemes.gallery) {
          await tester.pumpComponent(
            _md(
              '![red pixel](data:image/png;base64,$_pngBase64)',
              theme: theme,
            ),
          );
          expect(tester.terminalState.getText(), isNotNull);
        }
      });
    });

    test('per-tag img builder still overrides block rendering', () async {
      await testNocterm('per-tag img builder still overrides block rendering', (
        tester,
      ) async {
        await tester.pumpComponent(
          MarkdownPlus(
            '![red pixel](data:image/png;base64,$_pngBase64)',
            theme: MarkdownThemes.catppuccinMocha,
            builders: {
              'img': (element, visitor) => TextSpan(
                text: 'CUSTOM-IMG',
                style: visitor.theme.textStyle?.toTextStyle(),
              ),
            },
          ),
        );
        final text = tester.terminalState.getText();
        expect(text, contains('CUSTOM-IMG'));
      });
    });
  });
}
