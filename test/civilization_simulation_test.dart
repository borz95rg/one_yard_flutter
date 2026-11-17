import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/civilization_simulation.dart';
import 'package:one_yard_flutter/game/isometric_grid.dart';
import 'package:one_yard_flutter/game/resident_simulation.dart';

ResidentAgent resident(int id, {required int settlement, int? family}) =>
    ResidentAgent(
      id: id,
      name: 'Житель $id',
      position: const IsometricPoint(0, 0),
      gender: id.isEven ? 'Ж' : 'М',
      age: 120,
      personality: 'normal',
      needs: ResidentNeeds(.2, .2, .2),
      morale: .7,
      wallet: 15,
      familyId: family,
      settlementIndex: settlement,
    );

void main() {
  test('migration moves an entire household and keeps total residents', () {
    final simulation = CivilizationSimulation();
    final origin = simulation.worldSettlements[1]
      ..unlocked = true
      ..population = 12;
    final destination = simulation.worldSettlements[2]
      ..unlocked = true
      ..population = 5;
    final first = resident(101, settlement: 1, family: 101)..spouseId = 102;
    final second = resident(102, settlement: 1, family: 101)..spouseId = 101;
    final residents = [first, second];

    final moved = simulation.transferResidents(origin, destination, residents);

    expect(moved.map((resident) => resident.id), containsAll([101, 102]));
    expect(origin.population, 10);
    expect(destination.population, 7);
    expect(origin.population + destination.population, 17);
    expect(residents.map((resident) => resident.settlementIndex), [2, 2]);
    expect(simulation.migrations, 2);
    expect(first.spouseId, 102);
    expect(second.spouseId, 101);
    final restored =
        ResidentAgent.fromJson(Map<String, dynamic>.from(first.toJson()));
    expect(restored.settlementIndex, 2);
  });

  test('migration can return residents to the capital', () {
    final simulation = CivilizationSimulation();
    final satellite = simulation.worldSettlements[1]
      ..unlocked = true
      ..population = 8;
    final capital = simulation.worldSettlements[0]
      ..unlocked = true
      ..population = 20;
    final residents = [
      resident(201, settlement: 1),
      resident(202, settlement: 0),
      resident(203, settlement: 0),
      resident(204, settlement: 0),
    ];

    final moved = simulation.transferResidents(satellite, capital, residents);

    expect(moved, hasLength(1));
    expect(moved.single.settlementIndex, 0);
    expect(satellite.population, 7);
    expect(capital.population, 21);
  });

  test('locked cities and transfers that empty an origin are refused', () {
    final simulation = CivilizationSimulation();
    final origin = simulation.worldSettlements[1]
      ..unlocked = true
      ..population = 3;
    final destination = simulation.worldSettlements[2]
      ..unlocked = false
      ..population = 0;
    final residents = [resident(301, settlement: 1)];

    expect(
        simulation.transferResidents(origin, destination, residents), isEmpty);
    destination.unlocked = true;
    expect(
        simulation.transferResidents(origin, destination, residents), isEmpty);
    expect(origin.population, 3);
    expect(destination.population, 0);
    expect(residents.single.settlementIndex, 1);
    expect(simulation.migrations, 0);
  });

  test('migration does not split relatives already living in different cities',
      () {
    final simulation = CivilizationSimulation();
    final origin = simulation.worldSettlements[1]
      ..unlocked = true
      ..population = 3;
    final destination = simulation.worldSettlements[2]
      ..unlocked = true
      ..population = 5;
    final residents = [
      resident(401, settlement: 1, family: 401),
      resident(402, settlement: 2, family: 401),
      resident(403, settlement: 1),
      resident(404, settlement: 1),
      resident(405, settlement: 1),
    ];

    expect(
        simulation.transferResidents(origin, destination, residents), isEmpty);
    expect(origin.population, 3);
    expect(destination.population, 5);
    expect(residents.first.settlementIndex, 1);
    expect(simulation.migrations, 0);
  });
}
