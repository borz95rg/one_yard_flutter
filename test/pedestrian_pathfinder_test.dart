import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/isometric_grid.dart';
import 'package:one_yard_flutter/game/pedestrian_pathfinder.dart';

void main() {
  test('finds shortest route through connected sidewalks', () {
    final cells = [for (var x = 0; x < 4; x++) GridCell(x, 0)];
    final finder = PedestrianPathfinder(cells.map((c) => PedestrianNode(cell: c)));
    expect(finder.findRoute(cells.first, cells.last), cells);
  });

  test('pedestrian waits while crossing signal is red', () {
    final finder = PedestrianPathfinder([
      const PedestrianNode(cell: GridCell(0, 0)),
      const PedestrianNode(cell: GridCell(1, 0), type: PedestrianNodeType.crossing),
      const PedestrianNode(cell: GridCell(2, 0)),
    ]);
    expect(finder.findRoute(const GridCell(0, 0), const GridCell(2, 0), pedestrianGreen: false), isEmpty);
    expect(finder.findRoute(const GridCell(0, 0), const GridCell(2, 0), pedestrianGreen: true), hasLength(3));
  });

  test('does not route through disabled nodes or blocked edges', () {
    final a = const GridCell(0, 0), b = const GridCell(1, 0), c = const GridCell(2, 0);
    final finder = PedestrianPathfinder([
      PedestrianNode(cell: a),
      PedestrianNode(cell: b),
      PedestrianNode(cell: c),
    ], blockedEdges: [{a, b}]);
    expect(finder.findRoute(a, c), isEmpty);
  });
}
