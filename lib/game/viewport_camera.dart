/// Dependency-free camera math for the Flutter + Flame migration.
///
/// Coordinates use logical pixels. `center` is the world point shown at the
/// center of the viewport. The class deliberately contains no Flutter/Flame
/// imports so the math can be tested independently and adapted to Flame's
/// CameraComponent later.
class CameraPoint {
  const CameraPoint(this.x, this.y);

  final double x;
  final double y;

  CameraPoint operator +(CameraPoint other) =>
      CameraPoint(x + other.x, y + other.y);
  CameraPoint operator -(CameraPoint other) =>
      CameraPoint(x - other.x, y - other.y);
  CameraPoint operator *(double factor) => CameraPoint(x * factor, y * factor);
}

class ViewportCamera {
  ViewportCamera({
    this.center = const CameraPoint(0, 0),
    double zoom = 1,
    this.minZoom = 0.45,
    this.maxZoom = 3.5,
  }) : zoom = zoom.clamp(minZoom, maxZoom).toDouble() {
    if (minZoom <= 0 || maxZoom < minZoom) {
      throw ArgumentError('Invalid zoom limits');
    }
  }

  CameraPoint center;
  double zoom;
  final double minZoom;
  final double maxZoom;

  /// Moves the camera by a screen-space drag delta.
  /// Dragging the map right reveals world content to the left.
  void panBy(CameraPoint screenDelta) {
    center = center - screenDelta * (1 / zoom);
  }

  /// Zooms around a screen-space focal point, keeping the world point under
  /// the user's fingers stationary (two-finger pinch behavior).
  void zoomAt(CameraPoint focalPoint, double scaleFactor,
      {double viewportWidth = 0, double viewportHeight = 0}) {
    if (scaleFactor <= 0) return;

    final oldZoom = zoom;
    final nextZoom = (oldZoom * scaleFactor).clamp(minZoom, maxZoom).toDouble();
    if (nextZoom == oldZoom) return;

    final viewportCenter = CameraPoint(viewportWidth / 2, viewportHeight / 2);
    final offsetFromCenter = focalPoint - viewportCenter;
    final worldAnchor = center + offsetFromCenter * (1 / oldZoom);

    zoom = nextZoom;
    center = worldAnchor - offsetFromCenter * (1 / nextZoom);
  }

  /// Converts a screen coordinate to a world coordinate.
  CameraPoint screenToWorld(
    CameraPoint screenPoint, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final viewportCenter = CameraPoint(viewportWidth / 2, viewportHeight / 2);
    return center + (screenPoint - viewportCenter) * (1 / zoom);
  }

  /// Converts a world coordinate to a screen coordinate.
  CameraPoint worldToScreen(
    CameraPoint worldPoint, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    final viewportCenter = CameraPoint(viewportWidth / 2, viewportHeight / 2);
    return viewportCenter + (worldPoint - center) * zoom;
  }

  void reset({CameraPoint to = const CameraPoint(0, 0)}) {
    center = to;
    zoom = 1;
  }
}
