import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

import '../example/demo.dart' show MarkdownGallery;

void main() {
  test('gallery starts on first theme and cycles', () async {
    await testNocterm('gallery starts on first theme and cycles', (
      tester,
    ) async {
      await tester.pumpComponent(const MarkdownGallery());
      final initial = tester.terminalState.getText();
      expect(initial, contains('catppuccin-mocha (1/19)'));
      expect(initial, contains('Features'));

      await tester.sendKey(LogicalKey.arrowRight);
      final second = tester.terminalState.getText();
      expect(second, contains('nord (2/19)'));

      await tester.sendKey(LogicalKey.arrowLeft);
      expect(
        tester.terminalState.getText(),
        contains('catppuccin-mocha (1/19)'),
      );

      await tester.sendKey(LogicalKey.keyM);
      expect(tester.terminalState.getText(), contains('Features'));

      await tester.sendKey(LogicalKey.keyH);
      expect(tester.terminalState.getText(), contains('void main()'));
    });
  });
}
