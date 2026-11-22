import 'isometric_grid.dart';

enum PedestrianNodeType { sidewalk, crossing, entrance, park }

/// A walkable node in the pedestrian network. Coordinates are grid cells,
/// not screen pixels, so routes remain valid when the camera moves or zooms.
class PedestrianNode {
  const PedestrianNode({
    required this.cell,
    this.type = PedestrianNodeType.sidewalk,
    this.enabled = true,
  });

  final GridCell cell;
  final PedestrianNodeType type;
  final bool enabled;
}

class PedestrianPathfinder {
  PedestrianPathfinder(Iterable<PedestrianNode> nodes,
      {Iterable<Set<GridCell>> blockedEdges = const []})
      : nodes = {for (final node in nodes) node.cell: node},
        blockedEdges = blockedEdges.map(_edgeKey).toSet();

  final Map<GridCell, PedestrianNode> nodes;
  final Set<String> blockedEdges;

  /// Finds a shortest walkable route. Crossing nodes are usable only while
  /// the pedestrian signal is green. Returns an empty list if unreachable.
  List<GridCell> findRoute(
    GridCell start,
    GridCell goal, {
    bool pedestrianGreen = true,
  }) {
    final startNode = nodes[start];
    final goalNode = nodes[goal];
    if (startNode == null || goalNode == null ||
        !startNode.enabled || !goalNode.enabled) return const [];
    if (_isCrossing(startNode) && !pedestrianGreen ||
        _isCrossing(goalNode) && !pedestrianGreen) return const [];
    if (start == goal) return [start];

    final frontier = PriorityQueue<_Entry>((a, b) => a.priority.compareTo(b.priority));
    final cost = <GridCell, int>{start: 0};
    final previous = <GridCell, GridCell>{};
    frontier.add(_Entry(start, 0, 0));

    while (frontier.isNotEmpty) {
      final current = frontier.removeFirst();
      if (current.g != cost[current.cell]) continue;
      if (current.cell == goal) break;
      for (final next in _neighbors(current.cell)) {
        final node = nodes[next];
        if (node == null || !node.enabled ||
            (_isCrossing(node) && !pedestrianGreen) ||
            blockedEdges.contains(_edgeKey({current.cell, next}))) continue;
        final nextCost = current.g +
            (node.type == PedestrianNodeType.crossing ? 3 : 1);
        if (nextCost >= (cost[next] ?? 1 << 30)) continue;
        cost[next] = nextCost;
        previous[next] = current.cell;
        frontier.add(_Entry(next, nextCost + _heuristic(next, goal), nextCost));
      }
    }
    if (!previous.containsKey(goal)) return const [];
    final route = <GridCell>[goal];
    var cursor = goal;
    while (cursor != start) {
      cursor = previous[cursor]!;
      route.add(cursor);
    }
    return route.reversed.toList(growable: false);
  }

  Iterable<GridCell> _neighbors(GridCell cell) sync* {
    const offsets = [GridCell(1, 0), GridCell(-1, 0), GridCell(0, 1), GridCell(0, -1)];
    for (final offset in offsets) {
      yield GridCell(cell.column + offset.column, cell.row + offset.row);
    }
  }

  static bool _isCrossing(PedestrianNode node) => node.type == PedestrianNodeType.crossing;
  static int _heuristic(GridCell a, GridCell b) =>
      (a.column - b.column).abs() + (a.row - b.row).abs();
  static String _edgeKey(Set<GridCell> edge) {
    final sorted = edge.toList()..sort((a, b) => a.column != b.column
        ? a.column.compareTo(b.column) : a.row.compareTo(b.row));
    return '${sorted[0].column},${sorted[0].row}|${sorted[1].column},${sorted[1].row}';
  }
}

class _Entry {
  const _Entry(this.cell, this.priority, this.g);
  final GridCell cell;
  final int priority;
  final int g;
}

/// Small binary heap used by A* without adding a package dependency.
class PriorityQueue<T> {
  PriorityQueue(this.compare);
  final int Function(T, T) compare;
  final List<T> _items = [];
  bool get isNotEmpty => _items.isNotEmpty;
  void add(T value) {
    _items.add(value);
    var i = _items.length - 1;
    while (i > 0) {
      final p = (i - 1) ~/ 2;
      if (compare(_items[p], value) <= 0) break;
      _items[i] = _items[p];
      i = p;
    }
    _items[i] = value;
  }
  T removeFirst() {
    final result = _items.first;
    final last = _items.removeLast();
    if (_items.isEmpty) return result;
    var i = 0;
    while (true) {
      final left = i * 2 + 1;
      if (left >= _items.length) break;
      final right = left + 1;
      final child = right < _items.length && compare(_items[right], _items[left]) < 0 ? right : left;
      if (compare(last, _items[child]) <= 0) break;
      _items[i] = _items[child];
      i = child;
    }
    _items[i] = last;
    return result;
  }
}
