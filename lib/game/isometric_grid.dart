/// Dependency-free isometric grid geometry for the settlement map.
///
/// A tile is a diamond whose horizontal and vertical diagonals are
/// [tileWidth] and [tileHeight]. Grid coordinates refer to tile centers.
class GridCell {
  const GridCell(this.column, this.row);

  final int column;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);

  @override
  String toString() => 'GridCell($column, $row)';
}

class IsometricPoint {
  const IsometricPoint(this.x, this.y);

  final double x;
  final double y;
}

class IsometricGrid {
  IsometricGrid({
    required this.columns,
    required this.rows,
    this.tileWidth = 64,
    this.tileHeight = 32,
  }) {
    if (columns <= 0 || rows <= 0) {
      throw ArgumentError('Grid dimensions must be positive');
    }
    if (!tileWidth.isFinite || !tileHeight.isFinite ||
        tileWidth <= 0 || tileHeight <= 0) {
      throw ArgumentError('Tile dimensions must be finite and positive');
    }
  }

  final int columns;
  final int rows;
  final double tileWidth;
  final double tileHeight;

  /// Converts a tile coordinate to its center in isometric world space.
  IsometricPoint cellCenter(GridCell cell) => IsometricPoint(
        (cell.column - cell.row) * tileWidth / 2,
        (cell.column + cell.row) * tileHeight / 2,
      );

  /// Converts isometric world coordinates to fractional grid coordinates.
  IsometricPoint worldToGrid(IsometricPoint point) => IsometricPoint(
        point.x / tileWidth + point.y / tileHeight,
        point.y / tileHeight - point.x / tileWidth,
      );

  /// Converts fractional grid coordinates to isometric world coordinates.
  IsometricPoint gridToWorld(IsometricPoint grid) => IsometricPoint(
        (grid.x - grid.y) * tileWidth / 2,
        (grid.x + grid.y) * tileHeight / 2,
      );

  /// Returns the tile under [point], or null when outside the grid/diamond.
  /// Points on a shared edge are assigned to the nearest tile center.
  GridCell? cellAt(IsometricPoint point) {
    final fractional = worldToGrid(point);
    final column = fractional.x.round();
    final row = fractional.y.round();
    if (column < 0 || column >= columns || row < 0 || row >= rows) {
      return null;
    }
    final center = cellCenter(GridCell(column, row));
    final normalizedDistance =
        (point.x - center.x).abs() / (tileWidth / 2) +
        (point.y - center.y).abs() / (tileHeight / 2);
    if (normalizedDistance > 1.0000001) return null;
    return GridCell(column, row);
  }

  bool contains(GridCell cell) => cell.column >= 0 &&
      cell.column < columns && cell.row >= 0 && cell.row < rows;
}
