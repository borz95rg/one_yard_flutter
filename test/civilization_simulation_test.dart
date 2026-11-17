import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/civilization_simulation.dart';

void main() {
  test('settlement migration transfers population without creating residents',
      () {
    final simulation = CivilizationSimulation();
    final origin = WorldSettlementState(
      name: 'Старый порт',
      kind: 'port',
      populationThreshold: 0,
      x: .2,
      y: .3,
      unlocked: true,
      population: 12,
    );
    final destination = WorldSettlementState(
      name: 'Новый порт',
      kind: 'port',
      populationThreshold: 0,
      x: .7,
      y: .6,
      unlocked: true,
      population: 5,
    );

    expect(simulation.transferResidents(origin, destination, 3), isTrue);
    expect(origin.population, 9);
    expect(destination.population, 8);
    expect(origin.population + destination.population, 17);
    expect(simulation.migrations, 3);
  });

  test('migration refuses locked, capital, or emptying transfers', () {
    final simulation = CivilizationSimulation();
    final origin = WorldSettlementState(
      name: 'Столица',
      kind: 'capital',
      populationThreshold: 0,
      x: .5,
      y: .5,
      unlocked: true,
      population: 20,
    );
    final destination = WorldSettlementState(
      name: 'Посёлок',
      kind: 'town',
      populationThreshold: 0,
      x: .8,
      y: .8,
      unlocked: false,
      population: 0,
    );

    expect(simulation.transferResidents(origin, destination, 1), isFalse);
    expect(origin.population, 20);
    expect(destination.population, 0);
    expect(simulation.migrations, 0);
  });
}
