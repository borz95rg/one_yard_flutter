import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/isometric_grid.dart';

void main() {
  final grid = IsometricGrid(columns: 20, rows: 12, tileWidth: 64, tileHeight: 32);

  test('cell centers round-trip through world and fractional grid coordinates', () {
    for (var row = 0; row < grid.rows; row++) {
      for (var column = 0; column < grid.columns; column++) {
        final cell = GridCell(column, row);
        final center = grid.cellCenter(cell);
        final fractional = grid.worldToGrid(center);
        expect(fractional.x, closeTo(column.toDouble(), 1e-10));
        expect(fractional.y, closeTo(row.toDouble(), 1e-10));
        expect(grid.cellAt(center), cell);
      }
    }
  });

  test('grid/world transforms are inverse for fractional coordinates', () {
    const fractional = IsometricPoint(4.25, 7.75);
    final world = grid.gridToWorld(fractional);
    final restored = grid.worldToGrid(world);
    expect(restored.x, closeTo(fractional.x, 1e-10));
    expect(restored.y, closeTo(fractional.y, 1e-10));
  });

  test('rejects points outside tile diamond and map bounds', () {
    expect(grid.cellAt(const IsometricPoint(0, 0)), GridCell(0, 0));
    expect(grid.cellAt(const IsometricPoint(16, 8)), GridCell(0, 0));
    expect(grid.cellAt(const IsometricPoint(17, 8)), isNull);
    expect(grid.cellAt(grid.cellCenter(const GridCell(20, 0))), isNull);
  });

  test('validates grid and tile dimensions', () {
    expect(() => IsometricGrid(columns: 0, rows: 2), throwsArgumentError);
    expect(() => IsometricGrid(columns: 2, rows: 2, tileWidth: 0), throwsArgumentError);
  });
}
