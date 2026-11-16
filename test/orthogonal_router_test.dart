import 'package:nocterm_markdown_plus/src/diagram/orthogonal_router.dart';
import 'package:test/test.dart';

void main() {
  group('orthogonal router', () {
    test('routes around a blocked cell', () {
      final blocked = <(int, int)>{(2, 1), (2, 2), (2, 3)};
      final path = routeOrthogonal(
        start: (0, 2),
        end: (4, 2),
        width: 6,
        height: 6,
        blocked: blocked,
      );
      expect(path, isNotNull);
      expect(path!.first, (0, 2));
      expect(path.last, (4, 2));
      // No blocked cell on the path.
      for (final p in path) {
        expect(blocked.contains(p), isFalse, reason: '$p blocked');
      }
    });

    test('returns null when fully blocked', () {
      final blocked = <(int, int)>{};
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          if (x != 0 || y != 0) blocked.add((x, y));
        }
      }
      final path = routeOrthogonal(
        start: (0, 0),
        end: (4, 4),
        width: 5,
        height: 5,
        blocked: blocked,
      );
      expect(path, isNull);
    });

    test('prefers straight lines (fewer turns)', () {
      final path = routeOrthogonal(
        start: (0, 0),
        end: (5, 0),
        width: 6,
        height: 6,
        blocked: <(int, int)>{},
      );
      expect(path, isNotNull);
      // All on same row.
      expect(path!.every((p) => p.$2 == 0), isTrue);
    });
  });
}
