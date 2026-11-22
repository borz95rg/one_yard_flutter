import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/resident_simulation.dart';
import 'package:one_yard_flutter/game/isometric_grid.dart';

void main() {
  test('pedestrians gently separate when spawned at the same position', () {
    final simulation = ResidentSimulation.restore(
      source: [
        {'id': 1, 'x': 0, 'y': 0, 'age': 100, 'gender': 'М'},
        {'id': 2, 'x': 0, 'y': 0, 'age': 100, 'gender': 'Ж'},
      ],
      sites: const [],
      width: 200,
      height: 200,
    );

    simulation.resolvePedestrianSpacing(dt: 1);
    final a = simulation.residents[0].position;
    final b = simulation.residents[1].position;
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    expect(dx * dx + dy * dy, greaterThan(0));
  });

  test('spacing rejects invalid frame time', () {
    final simulation = ResidentSimulation.initial(
      sites: const [], width: 100, height: 100, count: 0,
    );
    expect(() => simulation.resolvePedestrianSpacing(dt: -1),
        throwsArgumentError);
  });

  test('walking residents accelerate smoothly and keep facing velocity', () {
    final destination = ResidentSite(
      const IsometricPoint(80, 0), 'парк',
    );
    final simulation = ResidentSimulation.restore(
      source: [
        {'id': 1, 'x': 0, 'y': 0, 'age': 100, 'gender': 'М'},
      ],
      sites: [destination],
      width: 200,
      height: 200,
    );
    final resident = simulation.residents.single;
    resident
      ..target = destination
      ..activity = ResidentActivity.walking;

    simulation.update(.1);
    expect(resident.position.x, greaterThan(0));
    expect(resident.velocityX, greaterThan(0));
    expect(resident.velocityX, lessThan(55));
    expect(resident.position.y.abs(), lessThan(0.001));
  });

  test('walking resident does not overshoot a nearby destination', () {
    final destination = ResidentSite(
      const IsometricPoint(18, 0), 'парк',
    );
    final simulation = ResidentSimulation.restore(
      source: [
        {'id': 1, 'x': 0, 'y': 0, 'age': 100, 'gender': 'М'},
      ],
      sites: [destination],
      width: 200,
      height: 200,
    );
    final resident = simulation.residents.single
      ..target = destination
      ..activity = ResidentActivity.walking;

    simulation.update(1);
    expect(resident.position.x, lessThanOrEqualTo(destination.position.x));
  });

}
