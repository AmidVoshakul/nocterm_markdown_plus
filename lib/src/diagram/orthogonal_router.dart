library;

typedef GridPoint = (int, int);

List<GridPoint>? routeOrthogonal({
  required GridPoint start,
  required GridPoint end,
  required int width,
  required int height,
  required Set<GridPoint> blocked,
  int turnPenalty = 5,
}) {
  if (start == end) return [start];
  if (width <= 0 || height <= 0) return null;

  const dirs = <(int, int)>[(1, 0), (0, 1), (-1, 0), (0, -1)];
  int manhattan(int x, int y) => (x - end.$1).abs() + (y - end.$2).abs();
  int opposite(int d) => (d + 2) % 4;

  final pq = <_Node>[];
  void push(_Node n) {
    pq.add(n);
    pq.sort((a, b) {
      if (a.f != b.f) return a.f.compareTo(b.f);
      return a.g.compareTo(b.g);
    });
  }

  final gScore = <String, int>{};
  final cameFrom = <String, String?>{};
  String keyOf(int x, int y, int d) => '$x,$y,$d';

  for (var d = 0; d < 4; d++) {
    final nx = start.$1 + dirs[d].$1;
    final ny = start.$2 + dirs[d].$2;
    if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
    if (blocked.contains((nx, ny))) continue;
    final k = keyOf(nx, ny, d);
    gScore[k] = 1;
    cameFrom[k] = null;
    push(_Node(f: 1 + manhattan(nx, ny), g: 1, x: nx, y: ny, dir: d));
  }

  String? goalKey;
  while (pq.isNotEmpty) {
    final cur = pq.removeAt(0);
    final curKey = keyOf(cur.x, cur.y, cur.dir);
    if (cur.g > (gScore[curKey] ?? (1 << 30))) continue;
    if (cur.x == end.$1 && cur.y == end.$2) {
      goalKey = curKey;
      break;
    }
    for (var nd = 0; nd < 4; nd++) {
      if (nd == opposite(cur.dir)) continue;
      final nx = cur.x + dirs[nd].$1;
      final ny = cur.y + dirs[nd].$2;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      if (blocked.contains((nx, ny))) continue;
      final turnCost = (nd == cur.dir) ? 0 : turnPenalty;
      final ng = cur.g + 1 + turnCost;
      final nkey = keyOf(nx, ny, nd);
      if (ng < (gScore[nkey] ?? (1 << 30))) {
        gScore[nkey] = ng;
        cameFrom[nkey] = curKey;
        push(_Node(f: ng + manhattan(nx, ny), g: ng, x: nx, y: ny, dir: nd));
      }
    }
  }

  if (goalKey == null) return null;

  final path = <GridPoint>[];
  String? cur = goalKey;
  while (cur != null) {
    final parts = cur.split(',');
    path.add((int.parse(parts[0]), int.parse(parts[1])));
    cur = cameFrom[cur];
  }
  path.add(start);
  final reversed = path.reversed.toList();
  path.clear();
  path.addAll(reversed);

  final deduped = <GridPoint>[];
  for (final p in path) {
    if (deduped.isEmpty || deduped.last != p) deduped.add(p);
  }
  return deduped;
}

class _Node {
  _Node({
    required this.f,
    required this.g,
    required this.x,
    required this.y,
    required this.dir,
  });
  final int f;
  final int g;
  final int x;
  final int y;
  final int dir;
}
