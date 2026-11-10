import 'dart:math';

import 'world_state.dart';

/// Port of the source HTML updateNatureSystems() rules.
/// Rendering particles, UI notifications and resident/market mutations are
/// returned as data for the Flutter/Flame layer to apply.
class NatureSimulation {
  NatureSimulation({double Function()? random})
      : _random = random ?? _defaultRandom;

  final double Function() _random;
  static final Random _rng = Random();
  static double _defaultRandom() => _rng.nextDouble();

  NatureTickResult update({
    required WorldState state,
    required double dt,
    required int residentCount,
    required double food,
    int farmCount = 0,
    int technologyLevel = 1,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    var season = state.seasonIndex;
    var seasonTimer = state.seasonTimer + dt;
    var year = state.worldYear;
    var weather = state.weather;
    var weatherTimer = state.weatherTimer + dt;
    var eventTimer = state.natureEventTimer + dt;
    var nature = Map<String, double>.from(state.nature);
    var nextFood = food;
    var moraleDelta = 0.0;
    final events = <String>[];

    if (seasonTimer >= 55) {
      seasonTimer -= 55;
      season = (season + 1) % 4;
      if (season == 0) year++;
      if (season == 1) {
        final yieldBoost =
            max(0.35, nature['soil']! / 100) * (weather == 'Засуха' ? 0.35 : 1);
        final harvest = max(
            1,
            (residentCount * 0.08 * yieldBoost +
                    farmCount *
                        1.2 *
                        yieldBoost *
                        (1 + (technologyLevel - 1) * .08))
                .floor());
        nextFood += harvest;
        nature['harvests'] = nature['harvests']! + 1;
        events.add(
            'Весенний посев и ранний сбор с $farmCount ферм: +$harvest еды');
        nature['cropProgress'] = farmCount > 0 ? 0.18 : 0;
      } else if (season == 2) {
        final soilYield = max(0.3, nature['soil']! / 100);
        final weatherYield = weather == 'Засуха' ? .4 : 1.0;
        final farmHarvest = farmCount *
            3.2 *
            soilYield *
            weatherYield *
            (1 + (technologyLevel - 1) * .12);
        final harvest =
            max(1, (residentCount * 0.08 * soilYield + farmHarvest).floor());
        nextFood += harvest;
        nature['harvests'] = nature['harvests']! + 1;
        events.add('Осенний сбор урожая с $farmCount ферм: +$harvest еды');
        nature['cropProgress'] = 0;
      } else {
        events.add('Наступил сезон: ${seasonNames[season]}');
      }
      nature['forest'] =
          min(100.0, nature['forest']! + (season == 0 ? 1.5 : 0.4));
      nature['wildlife'] =
          min(100.0, nature['wildlife']! + (season == 0 ? 1 : 0.2));
      if (season == 3) {
        final winterCost = max(1, (residentCount * 0.08).ceil());
        nextFood = max(0.0, nextFood - winterCost.toDouble());
        if (nextFood < residentCount * 0.12) {
          moraleDelta -= 0.025;
          events.add(
              'Зимой не хватает продовольствия — настроение жителей падает');
        }
      }
    }

    if (weatherTimer >= 18) {
      weatherTimer = 0;
      final options = season == 3
          ? const ['Снегопад', 'Мороз', 'Ясно', 'Ветер']
          : season == 1
              ? const ['Дождь', 'Гроза', 'Ясно', 'Ветер']
              : const ['Дождь', 'Ясно', 'Туман', 'Ветер', 'Гроза'];
      final previous = weather;
      weather = options[(_random() * options.length)
          .floor()
          .clamp(0, options.length - 1)
          .toInt()];
      if (weather != previous && _random() < 0.35) {
        events.add('Погода изменилась: ${weather.toLowerCase()}');
      }
    }

    final settlementPressure = max(0, residentCount - 8) * 0.0007 * dt;
    nature['pollution'] =
        _clamp(nature['pollution']! + settlementPressure - 0.0015 * dt, 0, 100);
    if (residentCount > 12 && _random() < 0.0008 * dt) {
      nature['forest'] = max(5.0, nature['forest']! - 0.6);
      nature['soil'] = max(10.0, nature['soil']! - 0.3);
    }
    if (weather == 'Дождь' || weather == 'Снегопад') {
      nature['soil'] = min(100.0, nature['soil']! + 0.012 * dt);
    }
    if (weather == 'Засуха') {
      nature['soil'] = max(5.0, nature['soil']! - 0.04 * dt);
      nature['wildlife'] = max(5.0, nature['wildlife']! - 0.012 * dt);
    }
    if (nature['pollution']! > 55) {
      nature['wildlife'] = max(5.0, nature['wildlife']! - 0.012 * dt);
      nature['soil'] = max(5.0, nature['soil']! - 0.006 * dt);
    }

    if (eventTimer >= 38) {
      eventTimer = 0;
      final roll = _random();
      if (roll < 0.12) {
        weather = 'Засуха';
        nature['droughts'] = nature['droughts']! + 1;
        final loss = max(1, (nextFood * 0.08).floor());
        nextFood = max(0.0, nextFood - loss.toDouble());
        nature['soil'] = max(5.0, nature['soil']! - 9.0);
        events.add('Засуха повредила поля: потеряно $loss ед. еды');
      } else if (roll < 0.23 && season != 3) {
        nature['floods'] = nature['floods']! + 1;
        nature['soil'] = min(100.0, nature['soil']! + 5.0);
        final loss = max(1, (nextFood * 0.04).floor());
        nextFood = max(0.0, nextFood - loss.toDouble());
        moraleDelta -= 0.015;
        events.add('Наводнение затопило часть полей и дорог');
      } else if (roll < 0.34) {
        nature['storms'] = nature['storms']! + 1;
        weather = season == 3 ? 'Метель' : 'Шторм';
        nature['forest'] = max(5.0, nature['forest']! - 2.0);
        events.add('Сильная буря повредила деревья и постройки');
      } else if (roll < 0.40 && nature['forest']! > 12 && season != 3) {
        nature['wildfires'] = nature['wildfires']! + 1;
        nature['forest'] = max(5.0, nature['forest']! - 8.0);
        nature['wildlife'] = max(5.0, nature['wildlife']! - 5.0);
        events.add('Лесной пожар повредил природные территории');
      }
    }

    final updated = WorldState(
      seasonIndex: season,
      seasonTimer: seasonTimer,
      worldYear: year,
      weather: weather,
      weatherTimer: weatherTimer,
      currentEraIndex: state.currentEraIndex,
      nature: Map.unmodifiable(nature),
      natureEventTimer: eventTimer,
    );
    return NatureTickResult(
        state: updated,
        food: nextFood,
        residentMoraleDelta: moraleDelta,
        events: List.unmodifiable(events));
  }

  static const seasonNames = ['Весна', 'Лето', 'Осень', 'Зима'];
  static double _clamp(double value, double minValue, double maxValue) =>
      value.clamp(minValue, maxValue).toDouble();
}

class NatureTickResult {
  const NatureTickResult(
      {required this.state,
      required this.food,
      required this.residentMoraleDelta,
      required this.events});
  final WorldState state;
  final double food;

  /// Apply this delta to each resident's morale, with the HTML source's floor.
  final double residentMoraleDelta;
  final List<String> events;
}

