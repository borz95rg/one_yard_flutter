import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/world_state.dart';

void main() {
  test('maps the verified season, year, weather, era and ecology fields', () {
    final state = WorldState.fromLegacyHtml({
      'seasonIndex': 2,
      'seasonTimer': 14.5,
      'worldYear': 7,
      'weather': 'Дождь',
      'weatherTimer': 3,
      'currentEraIndex': 2,
      'nature': {'forest': 61, 'wildlife': 49, 'soil': 77, 'pollution': 12},
    });
    expect(state.seasonIndex, 2);
    expect(state.worldYear, 7);
    expect(state.weather, 'Дождь');
    expect(state.currentEraIndex, 2);
    expect(state.nature['forest'], 61);
    expect(state.nature['harvests'], 0);
  });

  test('clamps invalid indices and defaults missing or invalid values', () {
    final state = WorldState.fromLegacyHtml({
      'seasonIndex': 99,
      'worldYear': 0,
      'seasonTimer': -5,
      'weather': 42,
      'nature': {'forest': double.nan, 'soil': 'bad'},
    });
    expect(state.seasonIndex, 3);
    expect(state.worldYear, 1);
    expect(state.seasonTimer, 0);
    expect(state.weather, 'Ясно');
    expect(state.nature['forest'], 72);
    expect(state.nature['soil'], 78);
  });

  test('serializes and restores the typed world state', () {
    final original = WorldState.initial();
    final restored = WorldState.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
  });
}
