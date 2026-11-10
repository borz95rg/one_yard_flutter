import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/nature_simulation.dart';
import 'package:one_yard_flutter/game/world_state.dart';

void main() {
  test('season advances at 55 seconds and summer harvest follows HTML formula', () {
    final initial = WorldState.initial();
    final result = NatureSimulation(random: () => 0.9).update(
      state: initial, dt: 55, residentCount: 20, food: 10,
    );
    expect(result.state.seasonIndex, 1);
    expect(result.state.seasonTimer, 0);
    expect(result.state.nature['harvests'], 1);
    expect(result.food, 13); // floor(20 * .16 * .78)
    expect(result.events.single, contains('урожай'));
  });

  test('winter increments world year and consumes winter food', () {
    final winter = WorldState(
      seasonIndex: 3, seasonTimer: 54, worldYear: 4, weather: 'Ясно',
      weatherTimer: 0, currentEraIndex: 0, nature: WorldState.defaultNature,
    );
    final result = NatureSimulation(random: () => 0.9).update(
      state: winter, dt: 1, residentCount: 20, food: 10,
    );
    expect(result.state.seasonIndex, 0);
    expect(result.state.worldYear, 5);
    expect(result.food, 8); // ceil(20 * .08)
  });

  test('natural hazard roll reproduces drought counters and food loss', () {
    var calls = 0;
    final simulation = NatureSimulation(random: () {
      calls++;
      return calls == 1 ? 0.9 : 0.05;
    });
    final result = simulation.update(
      state: WorldState(
        seasonIndex: 0, seasonTimer: 0, worldYear: 1, weather: 'Ясно',
        weatherTimer: 0, currentEraIndex: 0, nature: WorldState.defaultNature,
        natureEventTimer: 37,
      ),
      dt: 1, residentCount: 20, food: 100,
    );
    expect(result.state.weather, 'Засуха');
    expect(result.state.nature['droughts'], 1);
    expect(result.food, 92);
    expect(result.state.nature['soil'], 69);
    expect(result.events.single, contains('Засуха'));
  });

  test('rejects negative or non-finite delta time', () {
    expect(() => NatureSimulation().update(
      state: WorldState.initial(), dt: -1, residentCount: 1, food: 0,
    ), throwsArgumentError);
    expect(() => NatureSimulation().update(
      state: WorldState.initial(), dt: double.nan, residentCount: 1, food: 0,
    ), throwsArgumentError);
  });
}
