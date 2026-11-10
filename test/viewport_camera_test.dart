import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/viewport_camera.dart';

void main() {
  group('ViewportCamera', () {
    test('screen/world conversions are inverse operations', () {
      final camera = ViewportCamera(center: const CameraPoint(120, 80), zoom: 2);
      const world = CameraPoint(240, 160);
      final screen = camera.worldToScreen(world,
          viewportWidth: 400, viewportHeight: 300);
      final restored = camera.screenToWorld(screen,
          viewportWidth: 400, viewportHeight: 300);
      expect(restored.x, closeTo(world.x, 1e-9));
      expect(restored.y, closeTo(world.y, 1e-9));
    });

    test('zoom keeps the focal world point stationary', () {
      final camera = ViewportCamera(center: const CameraPoint(50, 70));
      const focal = CameraPoint(130, 90);
      final before = camera.screenToWorld(focal,
          viewportWidth: 400, viewportHeight: 300);
      camera.zoomAt(focal, 2,
          viewportWidth: 400, viewportHeight: 300);
      final after = camera.screenToWorld(focal,
          viewportWidth: 400, viewportHeight: 300);
      expect(after.x, closeTo(before.x, 1e-9));
      expect(after.y, closeTo(before.y, 1e-9));
      expect(camera.zoom, 2);
    });

    test('zoom is clamped to configured limits', () {
      final camera = ViewportCamera(minZoom: 0.5, maxZoom: 2);
      camera.zoomAt(const CameraPoint(100, 100), 100);
      expect(camera.zoom, 2);
      camera.zoomAt(const CameraPoint(100, 100), 0.001);
      expect(camera.zoom, 0.5);
    });

    test('drag moves the camera in the opposite direction', () {
      final camera = ViewportCamera(center: const CameraPoint(10, 20), zoom: 2);
      camera.panBy(const CameraPoint(40, -20));
      expect(camera.center.x,  -10);
      expect(camera.center.y, 30);
    });
  });
}
