import 'dart:math';

import 'city_economy.dart';
import 'isometric_grid.dart';
import 'resident_simulation.dart';

class HouseholdState {
  HouseholdState({
    required this.id,
    required this.familyKey,
    required this.x,
    required this.y,
    required this.ownerId,
    required this.value,
    required this.homeSiteIndex,
    required this.memberIds,
    this.districtId,
    this.level = 1,
  });

  final int id;
  final int familyKey;
  final double x, y;
  int ownerId;
  double value;
  final int homeSiteIndex;
  final List<int> memberIds;
  int? districtId;
  int level;

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyKey': familyKey,
        'x': x,
        'y': y,
        'ownerId': ownerId,
        'value': value,
        'homeSiteIndex': homeSiteIndex,
        'memberIds': memberIds,
        'districtId': districtId,
        'level': level,
      };

  factory HouseholdState.fromJson(Map data) => HouseholdState(
        id: _int(data['id'], 0),
        familyKey: _int(data['familyKey'], 0),
        x: _double(data['x'], 0),
        y: _double(data['y'], 0),
        ownerId: _int(data['ownerId'], 0),
        value: _double(data['value'], 80),
        homeSiteIndex: _int(data['homeSiteIndex'], -1),
        memberIds: data['memberIds'] is List
            ? (data['memberIds'] as List)
                .whereType<num>()
                .map((id) => id.toInt())
                .toList()
            : <int>[],
        districtId: _nullableInt(data['districtId']),
        level: _int(data['level'], 1).clamp(1, 3),
      );
}

class CityFaction {
  CityFaction({
    required this.id,
    required this.name,
    required this.color,
    required this.memberIds,
    required this.leaderId,
    required this.x,
    required this.y,
    required this.strength,
    required this.morale,
    required this.territory,
    required this.treasury,
    required this.food,
    required this.materials,
    required this.buildings,
    required this.district,
    this.expansionLevel = 1,
    this.tradeBalance = 0,
    this.conflictsWon = 0,
    this.conflictsLost = 0,
  });

  final int id;
  final String name;
  final int color;
  final List<int> memberIds;
  int leaderId;
  double x, y;
  double strength, morale, territory;
  double treasury, food, materials;
  final List<String> buildings;
  String district;
  int expansionLevel;
  double tradeBalance;
  int conflictsWon, conflictsLost;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'memberIds': memberIds,
        'leaderId': leaderId,
        'x': x,
        'y': y,
        'strength': strength,
        'morale': morale,
        'territory': territory,
        'treasury': treasury,
        'food': food,
        'materials': materials,
        'buildings': buildings,
        'district': district,
        'expansionLevel': expansionLevel,
        'tradeBalance': tradeBalance,
        'conflictsWon': conflictsWon,
        'conflictsLost': conflictsLost,
      };

  factory CityFaction.fromJson(Map data) => CityFaction(
        id: _int(data['id'], 0),
        name: _text(data['name'], 'Городская община'),
        color: _int(data['color'], 0xff4fb477),
        memberIds: data['memberIds'] is List
            ? (data['memberIds'] as List)
                .whereType<num>()
                .map((id) => id.toInt())
                .toList()
            : <int>[],
        leaderId: _int(data['leaderId'], 0),
        x: _double(data['x'], 0),
        y: _double(data['y'], 0),
        strength: _double(data['strength'], 10),
        morale: _double(data['morale'], .65).clamp(0, 1),
        territory: _double(data['territory'], 75),
        treasury: _double(data['treasury'], 24),
        food: _double(data['food'], 18),
        materials: _double(data['materials'], 8),
        buildings: data['buildings'] is List
            ? (data['buildings'] as List).whereType<String>().toList()
            : <String>['Штаб'],
        district: _text(data['district'], 'Новый квартал'),
        expansionLevel: _int(data['expansionLevel'], 1),
        tradeBalance: _double(data['tradeBalance'], 0),
        conflictsWon: _int(data['conflictsWon'], 0),
        conflictsLost: _int(data['conflictsLost'], 0),
      );
}

class WorldSettlementState {
  WorldSettlementState({
    required this.name,
    required this.kind,
    required this.populationThreshold,
    required this.x,
    required this.y,
    this.unlocked = false,
    this.population = 0,
    this.treasury = 0,
    this.food = 0,
    this.materials = 0,
    this.goods = 0,
    this.army = 0,
    this.tradeVolume = 0,
    this.foundedYear = 0,
    this.stability = .6,
  });

  final String name;
  final String kind;
  final int populationThreshold;
  final double x, y;
  bool unlocked;
  int population;
  double treasury, food, materials, goods, army, tradeVolume;
  int foundedYear;
  double stability;

  bool get isCapital => kind == 'capital';

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        'populationThreshold': populationThreshold,
        'x': x,
        'y': y,
        'unlocked': unlocked,
        'population': population,
        'treasury': treasury,
        'food': food,
        'materials': materials,
        'goods': goods,
        'army': army,
        'tradeVolume': tradeVolume,
        'foundedYear': foundedYear,
        'stability': stability,
      };

  factory WorldSettlementState.fromJson(Map data) => WorldSettlementState(
        name: _text(data['name'], 'Поселение'),
        kind: _text(data['kind'], 'town'),
        populationThreshold: _int(data['populationThreshold'], 0),
        x: _double(data['x'], .5).clamp(0, 1),
        y: _double(data['y'], .5).clamp(0, 1),
        unlocked: data['unlocked'] == true,
        population: _int(data['population'], 0).clamp(0, 1 << 31),
        treasury: _double(data['treasury'], 0),
        food: _double(data['food'], 0),
        materials: _double(data['materials'], 0),
        goods: _double(data['goods'], 0),
        army: _double(data['army'], 0),
        tradeVolume: _double(data['tradeVolume'], 0),
        foundedYear: _int(data['foundedYear'], 0),
        stability: _double(data['stability'], .6).clamp(0, 1),
      );

  static List<WorldSettlementState> seeded() => [
        WorldSettlementState(
          name: 'Первый двор',
          kind: 'capital',
          populationThreshold: 0,
          x: .22,
          y: .52,
          unlocked: true,
          population: 8,
          treasury: 110,
          food: 45,
          materials: 28,
          goods: 18,
          army: 3,
          foundedYear: 1,
        ),
        WorldSettlementState(
            name: 'Зелёная долина',
            kind: 'farm',
            populationThreshold: 15,
            x: .48,
            y: .24),
        WorldSettlementState(
            name: 'Речной порт',
            kind: 'port',
            populationThreshold: 30,
            x: .73,
            y: .40),
        WorldSettlementState(
            name: 'Северный округ',
            kind: 'town',
            populationThreshold: 50,
            x: .38,
            y: .79),
        WorldSettlementState(
            name: 'Горный край',
            kind: 'industry',
            populationThreshold: 75,
            x: .82,
            y: .78),
        WorldSettlementState(
            name: 'Новый центр',
            kind: 'metro',
            populationThreshold: 100,
            x: .57,
            y: .58),
      ];
}

class ForeignNationState {
  ForeignNationState({
    required this.name,
    required this.population,
    required this.territory,
    required this.relation,
    required this.treasury,
    required this.food,
    required this.materials,
    required this.goods,
    required this.army,
    this.technologyLevel = 1,
  });

  final String name;
  int population, territory, army, technologyLevel;
  double relation, treasury, food, materials, goods;
  bool get allied => relation >= 80;

  Map<String, dynamic> toJson() => {
        'name': name,
        'population': population,
        'territory': territory,
        'relation': relation,
        'treasury': treasury,
        'food': food,
        'materials': materials,
        'goods': goods,
        'army': army,
        'technologyLevel': technologyLevel,
      };

  factory ForeignNationState.fromJson(Map data) => ForeignNationState(
        name: _text(data['name'], 'Соседняя держава'),
        population: _int(data['population'], 1000).clamp(1, 1 << 31),
        territory: _int(data['territory'], 1).clamp(1, 1 << 31),
        relation: _double(data['relation'], 40).clamp(0, 100),
        treasury: _double(data['treasury'], 500),
        food: _double(data['food'], 400),
        materials: _double(data['materials'], 260),
        goods: _double(data['goods'], 180),
        army: _int(data['army'], 40).clamp(0, 1 << 31),
        technologyLevel: _int(data['technologyLevel'], 1).clamp(1, 6),
      );

  static List<ForeignNationState> seeded() => [
        ForeignNationState(
          name: 'Северная лига',
          population: 2800,
          territory: 12,
          relation: 42,
          treasury: 1800,
          food: 1200,
          materials: 740,
          goods: 520,
          army: 145,
          technologyLevel: 3,
        ),
        ForeignNationState(
          name: 'Речной союз',
          population: 2100,
          territory: 9,
          relation: 55,
          treasury: 1450,
          food: 900,
          materials: 620,
          goods: 850,
          army: 105,
          technologyLevel: 3,
        ),
        ForeignNationState(
          name: 'Горные княжества',
          population: 1650,
          territory: 14,
          relation: 30,
          treasury: 1250,
          food: 720,
          materials: 940,
          goods: 430,
          army: 128,
          technologyLevel: 2,
        ),
      ];
}

/// Citywide systems ported from the source game's education, health,
/// government, culture, diplomacy, era and world-network updates.
class CivilizationSimulation {
  CivilizationSimulation({Random? random}) : _random = random ?? Random() {
    worldSettlements.addAll(WorldSettlementState.seeded());
    foreignNations.addAll(ForeignNationState.seeded());
  }

  final Random _random;
  int technologyLevel = 1;
  double researchPoints = 0;
  int eraIndex = 0;
  int year = 1;
  double cityApproval = .62;
  int? rulerId;
  String nationName = 'Союз Дворовых Земель';
  int army = 0;
  int territory = 1;
  double prestige = 0;
  int campaigns = 0;
  int victories = 0;
  int defeats = 0;
  int outbreaks = 0;
  int recovered = 0;
  int treated = 0;
  int fireIncidents = 0;
  int firesPrevented = 0;
  int crimes = 0;
  int crimesResolved = 0;
  bool preventionEnabled = true;
  int festivals = 0;
  int monuments = 0;
  int cultureLevel = 1;
  double culturePoints = 0;
  double heritage = 0;
  double festivalCooldown = 0;
  String tradition = 'Память предков';
  String dominantCulture = 'Общие традиции';
  double worldTradeVolume = 0;
  int migrations = 0;
  int foundedSettlements = 1;
  final Map<String, double> diplomacy = {
    'Северная лига': 42,
    'Речной союз': 55,
    'Горные княжества': 30,
  };
  final Set<String> civicBuildings = {};
  final List<CityFaction> factions = [];
  final List<HouseholdState> households = [];
  final List<WorldSettlementState> worldSettlements = [];
  final List<ForeignNationState> foreignNations = [];
  final Map<String, int> milestones = {};
  double _yearTimer = 0;
  double _educationTimer = 0;
  double _healthTimer = 0;
  double _researchTimer = 0;
  double _cultureTimer = 0;
  double _civicTimer = 0;
  double _tradeTimer = 0;
  double _socialTimer = 0;
  double _factionTimer = 0;
  double _conflictTimer = 0;
  double _householdTimer = 0;
  int _diplomacyIndex = 0;
  int _nextFactionId = 1;
  int _nextHomeId = 1;

  static const eras = [
    ('Каменный век', 1, 0, 1),
    ('Бронзовый век', 2, 10, 3),
    ('Железный век', 3, 18, 8),
    ('Средневековье', 4, 30, 15),
    ('Индустриальная эпоха', 5, 50, 25),
    ('Современная эпоха', 6, 75, 40),
  ];
  static const _researchThresholds = [100.0, 250, 500, 900, 1450];
  static const _traditions = [
    'Память предков',
    'Праздник урожая',
    'Морские сказания',
    'Ремесленная гордость',
    'Научное любопытство',
    'Городское единство',
    'Путь исследователей',
  ];

  int get alliances => diplomacy.values.where((value) => value >= 80).length;
  int get affiliatedResidents =>
      factions.fold(0, (n, f) => n + f.memberIds.length);
  String get currentEra => eras[eraIndex.clamp(0, eras.length - 1)].$1;
  double get nextResearchTarget => technologyLevel >= 6
      ? 0
      : _researchThresholds[technologyLevel - 1].toDouble();
  double get researchProgress => technologyLevel >= 6
      ? 1
      : (researchPoints / nextResearchTarget).clamp(0, 1).toDouble();
  int get sickCount => _sickCount;
  int _sickCount = 0;

  Map<String, dynamic> toJson() => {
        'technologyLevel': technologyLevel,
        'researchPoints': researchPoints,
        'eraIndex': eraIndex,
        'year': year,
        'yearTimer': _yearTimer,
        'cityApproval': cityApproval,
        'rulerId': rulerId,
        'nationName': nationName,
        'army': army,
        'territory': territory,
        'prestige': prestige,
        'campaigns': campaigns,
        'victories': victories,
        'defeats': defeats,
        'outbreaks': outbreaks,
        'recovered': recovered,
        'treated': treated,
        'fireIncidents': fireIncidents,
        'firesPrevented': firesPrevented,
        'crimes': crimes,
        'crimesResolved': crimesResolved,
        'preventionEnabled': preventionEnabled,
        'festivals': festivals,
        'monuments': monuments,
        'cultureLevel': cultureLevel,
        'culturePoints': culturePoints,
        'heritage': heritage,
        'festivalCooldown': festivalCooldown,
        'tradition': tradition,
        'dominantCulture': dominantCulture,
        'worldTradeVolume': worldTradeVolume,
        'migrations': migrations,
        'foundedSettlements': foundedSettlements,
        'worldSettlements': worldSettlements.map((city) => city.toJson()).toList(),
        'foreignNations': foreignNations.map((state) => state.toJson()).toList(),
        'diplomacy': diplomacy,
        'civicBuildings': civicBuildings.toList(),
        'factions': factions.map((faction) => faction.toJson()).toList(),
        'households': households.map((home) => home.toJson()).toList(),
        'milestones': milestones,
        'educationTimer': _educationTimer,
        'healthTimer': _healthTimer,
        'researchTimer': _researchTimer,
        'cultureTimer': _cultureTimer,
        'civicTimer': _civicTimer,
        'tradeTimer': _tradeTimer,
        'diplomacyIndex': _diplomacyIndex,
        'socialTimer': _socialTimer,
        'factionTimer': _factionTimer,
        'conflictTimer': _conflictTimer,
        'nextFactionId': _nextFactionId,
        'householdTimer': _householdTimer,
        'nextHomeId': _nextHomeId,
      };

  factory CivilizationSimulation.fromJson(Map<String, dynamic> data,
      {Random? random}) {
    final state = CivilizationSimulation(random: random)
      ..technologyLevel = _int(data['technologyLevel'], 1).clamp(1, 6)
      ..researchPoints = _double(data['researchPoints'], 0)
      ..eraIndex = _int(data['eraIndex'], 0).clamp(0, eras.length - 1)
      ..year = _int(data['year'], 1).clamp(1, 1 << 31)
      .._yearTimer = _double(data['yearTimer'], 0).clamp(0, 60)
      ..cityApproval = _double(data['cityApproval'], .62).clamp(.1, .95)
      ..rulerId = _nullableInt(data['rulerId'])
      ..nationName = _text(data['nationName'], 'Союз Дворовых Земель')
      ..army = _int(data['army'], 0).clamp(0, 1 << 30)
      ..territory = _int(data['territory'], 1).clamp(1, 1 << 30)
      ..prestige = _double(data['prestige'], 0)
      ..campaigns = _int(data['campaigns'], 0)
      ..victories = _int(data['victories'], 0)
      ..defeats = _int(data['defeats'], 0)
      ..outbreaks = _int(data['outbreaks'], 0)
      ..recovered = _int(data['recovered'], 0)
      ..treated = _int(data['treated'], 0)
      ..fireIncidents = _int(data['fireIncidents'], 0)
      ..firesPrevented = _int(data['firesPrevented'], 0)
      ..crimes = _int(data['crimes'], 0)
      ..crimesResolved = _int(data['crimesResolved'], 0)
      ..preventionEnabled = data['preventionEnabled'] is bool
          ? data['preventionEnabled'] as bool
          : true
      ..festivals = _int(data['festivals'], 0)
      ..monuments = _int(data['monuments'], 0)
      ..cultureLevel = _int(data['cultureLevel'], 1).clamp(1, 10)
      ..culturePoints = _double(data['culturePoints'], 0)
      ..heritage = _double(data['heritage'], 0)
      ..festivalCooldown = _double(data['festivalCooldown'], 0).clamp(0, 45)
      ..tradition = _text(data['tradition'], 'Память предков')
      ..dominantCulture = _text(data['dominantCulture'], 'Общие традиции')
      ..worldTradeVolume = _double(data['worldTradeVolume'], 0)
      ..migrations = _int(data['migrations'], 0)
      ..foundedSettlements = _int(data['foundedSettlements'], 1).clamp(1, 6)
      .._educationTimer = _double(data['educationTimer'], 0).clamp(0, 6)
      .._healthTimer = _double(data['healthTimer'], 0).clamp(0, 8)
      .._researchTimer = _double(data['researchTimer'], 0).clamp(0, 12)
      .._cultureTimer = _double(data['cultureTimer'], 0).clamp(0, 8)
      .._civicTimer = _double(data['civicTimer'], 0).clamp(0, 12)
      .._tradeTimer = _double(data['tradeTimer'], 0).clamp(0, 12)
      .._diplomacyIndex = _int(data['diplomacyIndex'], 0);
    state
      .._socialTimer = _double(data['socialTimer'], 0).clamp(0, 3.5)
      .._factionTimer = _double(data['factionTimer'], 0).clamp(0, 6)
      .._conflictTimer = _double(data['conflictTimer'], 0).clamp(0, 8)
      .._nextFactionId = _int(data['nextFactionId'], 1).clamp(1, 1 << 31)
      .._householdTimer = _double(data['householdTimer'], 0).clamp(0, 8)
      .._nextHomeId = _int(data['nextHomeId'], 1).clamp(1, 1 << 31);
    if (data['factions'] is List) {
      state.factions.addAll((data['factions'] as List)
          .whereType<Map>()
          .map(CityFaction.fromJson));
      state._nextFactionId = max(state._nextFactionId,
          state.factions.fold(1, (next, faction) => max(next, faction.id + 1)));
    }
    if (data['households'] is List) {
      state.households.addAll((data['households'] as List)
          .whereType<Map>()
          .map(HouseholdState.fromJson));
      state._nextHomeId = max(state._nextHomeId,
          state.households.fold(1, (next, home) => max(next, home.id + 1)));
    }
    if (data['worldSettlements'] is List) {
      state.worldSettlements
        ..clear()
        ..addAll((data['worldSettlements'] as List)
            .whereType<Map>()
            .map(WorldSettlementState.fromJson));
    }
    if (data['foreignNations'] is List) {
      state.foreignNations
        ..clear()
        ..addAll((data['foreignNations'] as List)
            .whereType<Map>()
            .map(ForeignNationState.fromJson));
    }
    if (data['diplomacy'] is Map) {
      state.diplomacy
        ..clear()
        ..addEntries((data['diplomacy'] as Map)
            .entries
            .where((entry) => entry.key is String && entry.value is num)
            .map((entry) => MapEntry(entry.key as String,
                (entry.value as num).toDouble().clamp(0, 100))));
    }
    if (state.diplomacy.isEmpty) {
      state.diplomacy.addAll({
        'Северная лига': 42,
        'Речной союз': 55,
        'Горные княжества': 30,
      });
    }
    for (final foreign in state.foreignNations) {
      final relation = state.diplomacy[foreign.name];
      if (relation != null) foreign.relation = relation;
    }
    if (data['civicBuildings'] is List) {
      state.civicBuildings
          .addAll((data['civicBuildings'] as List).whereType<String>());
    }
    if (data['milestones'] is Map) {
      state.milestones.addEntries((data['milestones'] as Map)
          .entries
          .where((entry) => entry.key is String && entry.value is num)
          .map((entry) =>
              MapEntry(entry.key as String, (entry.value as num).toInt())));
    }
    return state;
  }

  factory CivilizationSimulation.fromLegacy(Map<String, dynamic> legacy,
      {Random? random}) {
    final data = <String, dynamic>{
      'technologyLevel': legacy['technologyLevel'],
      'researchPoints': legacy['researchPoints'],
      'eraIndex': legacy['currentEraIndex'],
      'year': (legacy['nation'] is Map
          ? (legacy['nation'] as Map)['year']
          : legacy['worldYear']),
      'yearTimer':
          legacy['nation'] is Map ? (legacy['nation'] as Map)['yearTimer'] : 0,
      'cityApproval': legacy['cityApproval'],
      'rulerId': legacy['cityLeaderId'],
      'nationName':
          legacy['nation'] is Map ? (legacy['nation'] as Map)['name'] : null,
      'army':
          legacy['nation'] is Map ? (legacy['nation'] as Map)['army'] : null,
      'territory': legacy['nation'] is Map
          ? (legacy['nation'] as Map)['territory']
          : null,
      'prestige': legacy['nation'] is Map
          ? (legacy['nation'] as Map)['prestige']
          : null,
      'campaigns': legacy['nation'] is Map
          ? (legacy['nation'] as Map)['campaigns']
          : null,
      'victories': legacy['nation'] is Map
          ? (legacy['nation'] as Map)['victories']
          : null,
      'defeats':
          legacy['nation'] is Map ? (legacy['nation'] as Map)['defeats'] : null,
      'outbreaks': (legacy['healthStats'] is Map
          ? (legacy['healthStats'] as Map)['outbreaks']
          : 0),
      'recovered': legacy['healthStats'] is Map
          ? (legacy['healthStats'] as Map)['recovered']
          : 0,
      'treated': legacy['healthStats'] is Map
          ? (legacy['healthStats'] as Map)['treated']
          : 0,
      'fireIncidents': legacy['healthStats'] is Map
          ? (legacy['healthStats'] as Map)['fireIncidents']
          : 0,
      'firesPrevented': legacy['healthStats'] is Map
          ? (legacy['healthStats'] as Map)['prevented']
          : 0,
      'preventionEnabled': legacy['preventionEnabled'],
      'festivals': legacy['culture'] is Map
          ? (legacy['culture'] as Map)['festivals']
          : 0,
      'monuments': legacy['culture'] is Map
          ? (legacy['culture'] as Map)['monuments']
          : 0,
      'cultureLevel':
          legacy['culture'] is Map ? (legacy['culture'] as Map)['level'] : 1,
      'culturePoints':
          legacy['culture'] is Map ? (legacy['culture'] as Map)['points'] : 0,
      'heritage':
          legacy['culture'] is Map ? (legacy['culture'] as Map)['heritage'] : 0,
      'festivalCooldown': legacy['culture'] is Map
          ? (legacy['culture'] as Map)['festivalCooldown']
          : 0,
      'tradition': legacy['culture'] is Map
          ? (legacy['culture'] as Map)['tradition']
          : null,
      'dominantCulture': legacy['culture'] is Map
          ? (legacy['culture'] as Map)['dominant']
          : null,
      'worldTradeVolume': legacy['worldTradeStats'] is Map
          ? (legacy['worldTradeStats'] as Map)['volume']
          : 0,
      'migrations': legacy['worldTradeStats'] is Map
          ? (legacy['worldTradeStats'] as Map)['migrations']
          : 0,
      'foundedSettlements': legacy['worldTradeStats'] is Map
          ? (legacy['worldTradeStats'] as Map)['founded']
          : 1,
      'diplomacy': legacy['nation'] is Map
          ? _relationsToMap((legacy['nation'] as Map)['relations'])
          : null,
      'civicBuildings': legacy['factions'] is List
          ? (legacy['factions'] as List)
              .whereType<Map>()
              .expand((f) => f['buildings'] is List
                  ? (f['buildings'] as List).whereType<String>()
                  : const <String>[])
              .toSet()
              .toList()
          : const <String>[],
      'factions':
          legacy['factions'] is List ? legacy['factions'] : const <Map>[],
      'households':
          legacy['households'] is List ? legacy['households'] : const <Map>[],
      'nextHomeId': legacy['nextHomeId'],
    };
    final state = CivilizationSimulation.fromJson(data, random: random);
    if (legacy['cityEvents'] is Map) {
      state.crimes = _int((legacy['cityEvents'] as Map)['crimes'], 0);
      state.crimesResolved = _int((legacy['cityEvents'] as Map)['resolved'], 0);
      state.fireIncidents = max(
          state.fireIncidents, _int((legacy['cityEvents'] as Map)['fires'], 0));
    }
    return state;
  }

  static Map<String, dynamic>? _relationsToMap(Object? value) {
    if (value is! List) return null;
    return {
      for (final item in value.whereType<Map>())
        if (item['name'] is String)
          item['name'] as String: _double(item['value'], 0),
    };
  }

  List<String> update({
    required double dt,
    required List<ResidentAgent> residents,
    required List<ResidentSite> sites,
    required MarketState market,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final events = <String>[];
    if (dt == 0) return events;
    _yearTimer += dt;
    while (_yearTimer >= 60) {
      _yearTimer -= 60;
      year++;
      if (year % 5 == 0) {
        events.add('📜 $year год: $nationName продолжает развиваться');
      }
    }
    festivalCooldown = max(0, festivalCooldown - dt);
    _educationTimer += dt;
    _healthTimer += dt;
    _researchTimer += dt;
    _cultureTimer += dt;
    _civicTimer += dt;
    _tradeTimer += dt;
    _socialTimer += dt;
    _factionTimer += dt;
    _conflictTimer += dt;
    _householdTimer += dt;

    if (_householdTimer >= 8) {
      _householdTimer %= 8;
      _ensureHouseholds(residents, sites);
    }

    while (_socialTimer >= 3.5) {
      _socialTimer -= 3.5;
      _formFactions(residents, events);
    }
    while (_factionTimer >= 6) {
      _factionTimer -= 6;
      _updateFactions(residents, events);
    }
    while (_conflictTimer >= 8) {
      _conflictTimer -= 8;
      _resolveFactionConflict(residents, events);
    }

    final factionBuildings = factions.expand((f) => f.buildings).toSet();

    final hasSchool = civicBuildings.contains('Школа') ||
        factionBuildings.contains('Школа') ||
        sites.any(
            (site) => _has(site.role, ['школа', 'колледж', 'университет']));
    final hasCollege = civicBuildings.contains('Колледж') ||
        factionBuildings.contains('Колледж') ||
        sites.any((site) => _has(site.role, ['колледж', 'университет']));
    final hasUniversity = civicBuildings.contains('Университет') ||
        factionBuildings.contains('Университет') ||
        sites.any((site) => site.role.toLowerCase().contains('университет'));
    final hasHospital = civicBuildings.contains('Больница') ||
        civicBuildings.contains('Медпункт') ||
        factionBuildings.contains('Больница') ||
        factionBuildings.contains('Медпункт') ||
        sites.any(
            (site) => _has(site.role, ['медпункт', 'больница', 'клиника']));
    final hasFireStation = civicBuildings.contains('Пожарная часть') ||
        factionBuildings.contains('Пожарная часть') ||
        sites.any((site) => site.role.toLowerCase().contains('пожар'));
    final hasPolice = civicBuildings.contains('Полицейский участок') ||
        factionBuildings.contains('Полицейский участок') ||
        sites.any((site) => site.role.toLowerCase().contains('полици'));
    final hasPark = civicBuildings.contains('Парк') ||
        factionBuildings.contains('Парк') ||
        sites.any((site) => site.role.toLowerCase().contains('парк'));
    final hasMarket = civicBuildings.contains('Рынок') ||
        factionBuildings.contains('Рынок') ||
        sites.any((site) => site.role.toLowerCase().contains('рынок'));

    for (final resident in residents) {
      _updateResident(resident, dt, sites,
          school: hasSchool,
          college: hasCollege,
          university: hasUniversity,
          clinic: hasHospital,
          market: hasMarket,
          park: hasPark);
      if (resident.activity == ResidentActivity.working &&
          resident.age >= 42 &&
          resident.age < 620) {
        final wage = _wage(resident.job);
        resident.wallet = (resident.wallet + wage * dt).clamp(0, 99999);
        market.treasury += wage * dt * market.taxRate;
      }
    }

    if (_educationTimer >= 6) {
      _educationTimer %= 6;
      for (final resident in residents) {
        if (resident.age < 42 && hasSchool) {
          resident.education = min(100, resident.education + 3);
        } else if (resident.age >= 42 && resident.age < 620) {
          if (hasCollege) {
            resident.education = min(100, resident.education + 1.8);
          }
          if (hasUniversity) {
            resident.education = min(100, resident.education + 1.1);
          }
        }
      }
      _assignJobs(residents);
    }

    if (_researchTimer >= 12) {
      _researchTimer %= 12;
      final scholars = residents
          .where((r) => r.age >= 42 && r.age < 620 && r.education >= 58)
          .length;
      final universities = hasUniversity ? 1 : 0;
      final colleges = hasCollege ? 1 : 0;
      researchPoints += scholars * (.35 + universities * .9 + colleges * .25);
      while (technologyLevel < 6 &&
          researchPoints >= _researchThresholds[technologyLevel - 1]) {
        technologyLevel++;
        events.add(
            '🔬 Открыта новая ступень технологий: уровень $technologyLevel');
      }
    }

    while (_civicTimer >= 6) {
      _civicTimer -= 6;
      _buildCivicMilestones(residents.length, market, events);
      _updateGovernment(residents, market, hasPolice, hasFireStation, events);
    }
    _updateHealth(dt, residents, market, hasHospital, hasFireStation, events);

    if (_cultureTimer >= 8) {
      _cultureTimer %= 8;
      _updateCulture(residents, sites.length, hasSchool, events);
    }
    if (_tradeTimer >= 12) {
      _tradeTimer %= 12;
      _updateWorldNetwork(residents, market, events);
    }
    _updateEra(residents.length, events);
    _updateNation(dt, residents, market, events);
    _sickCount = residents.where((r) => r.sick).length;
    return events;
  }

  void _updateWorldNetwork(List<ResidentAgent> residents, MarketState market,
      List<String> events) {
    for (var index = 0; index < worldSettlements.length; index++) {
      final city = worldSettlements[index];
      if (!city.unlocked && residents.length >= city.populationThreshold) {
        city
          ..unlocked = true
          ..population = max(3, (residents.length * (.12 + index * .035)).round())
          ..treasury = 45 + residents.length * .7
          ..food = 20 + city.population * (city.kind == 'farm' ? 3.2 : 1.6)
          ..materials = 8 + city.population * .55
          ..goods = 5 + city.population * .45
          ..army = max(1, city.population ~/ 24).toDouble()
          ..foundedYear = year;
        events.add('🏙️ Основано поселение «${city.name}»');
      }
      if (!city.unlocked) continue;

      if (city.isCapital) {
        city
          ..population = residents.length
          ..treasury = market.treasury
          ..food = market.food
          ..materials = market.materials
          ..goods = market.goods
          ..army = army.toDouble();
        continue;
      }

      final population = city.population.toDouble();
      var foodMade = 0.0, materialsMade = 0.0, goodsMade = 0.0;
      switch (city.kind) {
        case 'farm':
          foodMade = population * .18;
          break;
        case 'port':
          goodsMade = population * .14;
          foodMade = population * .035;
          break;
        case 'industry':
          materialsMade = population * .13;
          goodsMade = population * .045;
          break;
        case 'metro':
          foodMade = population * .07;
          materialsMade = population * .055;
          goodsMade = population * .09;
          break;
        default:
          foodMade = population * .07;
          goodsMade = population * .045;
      }
      city
        ..food = max(0, city.food + foodMade - population * .105)
        ..materials = max(0, city.materials + materialsMade - population * .018)
        ..goods = max(0, city.goods + goodsMade - population * .028);
      final foodExport = min(max(0, city.food - population * .7), population * .06);
      final materialExport =
          min(max(0, city.materials - population * .4), population * .035);
      final goodsExport = min(max(0, city.goods - population * .35), population * .04);
      final exportValue = foodExport * market.foodPrice +
          materialExport * market.materialPrice +
          goodsExport * market.goodsPrice;
      final maintenance = city.army * .035 + population * .018;
      city
        ..food -= foodExport
        ..materials -= materialExport
        ..goods -= goodsExport
        ..tradeVolume += foodExport + materialExport + goodsExport
        ..treasury = max(0, city.treasury + exportValue * .18 + population * .025 - maintenance)
        ..stability = (city.stability +
                (city.food > population * .5 ? .012 : -.035))
            .clamp(.08, 1)
            .toDouble();
      final exportTotal = foodExport + materialExport + goodsExport;
      worldTradeVolume += exportTotal;
      market.tradeVolume += exportTotal;
      market.food = min(9999, market.food + foodExport * .12);
      market.materials = min(9999, market.materials + materialExport * .1);
      market.goods = min(9999, market.goods + goodsExport * .12);

      if (city.stability > .52 &&
          city.food > population * .8 &&
          city.treasury > population * 2 &&
          _random.nextDouble() < .38) {
        city.population++;
      } else if (city.stability < .25 &&
          city.population > 3 &&
          _random.nextDouble() < .2) {
        city.population--;
        events.add('📉 В «${city.name}» жители уезжают из-за нехватки запасов');
      }
      if (city.army < city.population * .08 && city.treasury > 180) {
        city
          ..army += 1
          ..treasury -= 18;
      }
    }

    _simulateForeignNations(market);

    foundedSettlements = worldSettlements.where((city) => city.unlocked).length;
    if (foundedSettlements > 1 && _random.nextDouble() < .22) {
      final destinations = worldSettlements
          .where((city) => city.unlocked && !city.isCapital)
          .toList();
      if (destinations.isNotEmpty) {
        final destination = destinations[_random.nextInt(destinations.length)];
        destination.population++;
        migrations++;
        events.add('🚶 Переселенцы прибыли в ${destination.name}');
      }
    }
  }

  void _simulateForeignNations(MarketState market) {
    for (final state in foreignNations) {
      final population = state.population.toDouble();
      state
        ..food = max(0, state.food + population * .045 - population * .034)
        ..materials = max(0, state.materials + population * .014 - population * .012)
        ..goods = max(0, state.goods + population * .018 - population * .016)
        ..treasury = max(
            0,
            state.treasury +
                population * .032 +
                state.goods * .008 -
                state.army * .055 -
                population * .012);
      if (state.food < population * .22) {
        state.population = max(1, state.population - 1);
      } else if (state.food > population * .7 &&
          state.treasury > population * .6 &&
          _random.nextDouble() < .28) {
        state.population++;
      }
      if (state.army < state.population * .09 &&
          state.treasury > 240 &&
          _random.nextDouble() < .25) {
        state.army++;
        state.treasury -= 24;
      }
      if (state.allied && state.goods > state.population * .08) {
        final export = min(state.goods - state.population * .04,
            state.population * .018);
        state.goods -= export;
        market.goods = min(9999, market.goods + export);
        market.tradeVolume += export;
        worldTradeVolume += export;
        state.treasury += export * market.goodsPrice * .12;
      }
    }
  }

  void _updateResident(ResidentAgent r, double dt, List<ResidentSite> sites,
      {required bool school,
      required bool college,
      required bool university,
      required bool clinic,
      required bool market,
      required bool park}) {
    if (r.age < 42 && school && r.activity == ResidentActivity.working) {
      r.education = min(100, r.education + dt * .55);
    } else if (r.activity == ResidentActivity.working) {
      r.skill = min(100, r.skill + dt * .12);
    }
    final cleanWater = sites.any((site) =>
        _has(site.role.toLowerCase(),
            ['источник', 'озеро', 'море', 'колодец']) &&
        (site.position.x - r.position.x).abs() < 140 &&
        (site.position.y - r.position.y).abs() < 140);
    if (r.needs.hunger > .88 || r.needs.thirst > .9) {
      r.health = max(.15, r.health - dt * .0025);
      r.sick = true;
      r.illness ??= r.needs.hunger > .88 ? 'истощение' : 'обезвоживание';
    } else {
      r.health = min(1, r.health + dt * (clinic ? .012 : .003));
      if (r.health > .72) {
        r.sick = false;
        r.illness = null;
      }
    }
    if (!cleanWater && r.needs.thirst > .7) {
      r.health = max(.15, r.health - dt * .0008);
    }
    if (r.sick) {
      final care = (clinic ? .010 : 0) + (preventionEnabled ? .002 : 0);
      r.health = min(1, r.health + dt * (.0015 + care));
      if (r.health > .76) {
        r.sick = false;
        r.illness = null;
        r.immunity = max(r.immunity, .55);
        recovered++;
      }
    } else if (preventionEnabled) {
      r.immunity = min(.95, r.immunity + dt * .00035);
    }
    if (r.health < .32 && !r.sick) {
      r.sick = true;
      r.illness = 'ослабление здоровья';
    }
    r.happiness = (r.happiness + dt * (r.health - .7) * .0008).clamp(.05, 1);
    if (r.needs.hunger > .9) {
      r.happiness = max(.05, r.happiness - dt * .0007);
    }
    if (park) r.happiness = min(1, r.happiness + dt * .00015);
    if (college && r.education >= 58 && r.age >= 42 && r.job == 'Фермер') {
      r.job = 'Специалист';
    }
    if (university && r.education >= 82 && r.age >= 42) {
      r.job = r.personality == 'builder' ? 'Инженер' : 'Учёный';
    }
    if (market && r.wallet > 2 && _random.nextDouble() < dt * .025) {
      r.wallet -= 2;
      r.needs.hunger = max(0, r.needs.hunger - .16);
      r.happiness = min(1, r.happiness + .035);
    }
  }

  void _updateHealth(
      double dt,
      List<ResidentAgent> residents,
      MarketState market,
      bool hasHospital,
      bool fireStation,
      List<String> events) {
    if (_healthTimer < 8) return;
    _healthTimer %= 8;
    final sick = residents.where((r) => r.sick).toList();
    final hospitals = civicBuildings.contains('Больница') ? 1 : 0;
    final clinics = civicBuildings.contains('Медпункт') ? 1 : 0;
    final coverage = hospitals * .13 + clinics * .07;
    if (residents.length >= 12 &&
        sick.isEmpty &&
        _random.nextDouble() <
            (preventionEnabled ? .025 : .075) * min(2, residents.length / 25)) {
      final patient = residents[_random.nextInt(residents.length)];
      if (patient.immunity < .8) {
        patient.sick = true;
        patient.illness = 'сезонная инфекция';
        patient.health = min(patient.health, .68);
        outbreaks++;
        events.add('🦠 В городе обнаружен первый случай сезонной инфекции');
      }
    }
    var newCases = 0;
    for (final patient in sick) {
      for (final resident in residents.where((r) => !r.sick)) {
        final distance = (resident.position.x - patient.position.x).abs() +
            (resident.position.y - patient.position.y).abs();
        if (distance < 144 &&
            _random.nextDouble() <
                (preventionEnabled ? .018 : .065) *
                    (1 - resident.immunity) *
                    (1 - coverage)) {
          resident.sick = true;
          resident.illness = patient.illness ?? 'сезонная инфекция';
          resident.health = min(resident.health, .72);
          newCases++;
        }
      }
    }
    if (newCases > 0) {
      events.add('🩺 Медики зарегистрировали заболевших: $newCases');
    }
    final upkeep = hospitals * 1.25 + clinics * .55;
    if (market.treasury >= upkeep) market.treasury -= upkeep;
    if (sick.isNotEmpty && hasHospital) {
      treated += min(sick.length, hospitals * 2 + clinics);
    }
    if (residents.length >= 10 && _random.nextDouble() < .018) {
      if (fireStation) {
        firesPrevented++;
        events.add('🚒 Пожарная служба предотвратила возгорание');
      } else {
        fireIncidents++;
        cityApproval = max(.1, cityApproval - .012);
        events.add('🔥 Пожар в поселении: нужна пожарная часть');
      }
    }
  }

  void _buildCivicMilestones(
      int population, MarketState market, List<String> events) {
    final facilities = [
      (8, 'Школа', 65.0, 18.0),
      (10, 'Пожарная часть', 75.0, 22.0),
      (12, 'Полицейский участок', 120.0, 30.0),
      (14, 'Рынок', 28.0, 8.0),
      (16, 'Больница', 105.0, 30.0),
      (20, 'Ратуша', 130.0, 38.0),
      (22, 'Колледж', 190.0, 48.0),
      (30, 'Университет', 340.0, 82.0),
      (50, 'Транспортное депо', 190.0, 45.0),
    ];
    for (final (count, name, coins, materials) in facilities) {
      if (population < count || civicBuildings.contains(name)) continue;
      if (market.treasury < coins || market.materials < materials) continue;
      market.treasury -= coins;
      market.materials -= materials;
      civicBuildings.add(name);
      events.add('🏛️ Город открыл: $name');
    }
  }

  void _updateGovernment(List<ResidentAgent> residents, MarketState market,
      bool hasPolice, bool hasFireStation, List<String> events) {
    final adults = residents.where((r) => r.age >= 42 && r.age < 620).toList();
    if (rulerId == null && residents.length >= 8 && adults.isNotEmpty) {
      adults.sort((a, b) => (b.education + b.morale * 100)
          .compareTo(a.education + a.morale * 100));
      rulerId = adults.first.id;
      events.add('👑 ${adults.first.name} стал правителем');
    }
    if (rulerId != null && !residents.any((r) => r.id == rulerId)) {
      rulerId = null;
    }
    if (army > 0) market.treasury = max(0, market.treasury - army * .012);
    final average = residents.isEmpty
        ? .62
        : residents.fold<double>(0, (sum, r) => sum + r.happiness) /
            residents.length;
    cityApproval =
        (cityApproval + (average - cityApproval) * .08).clamp(.1, .95);
    if (residents.length >= 12 && _random.nextDouble() < .045) {
      crimes++;
      if (hasPolice || civicBuildings.contains('Полицейский участок')) {
        crimesResolved++;
        events.add('🚓 Полиция раскрыла кражу');
      } else {
        cityApproval = max(.1, cityApproval - .025);
        events.add('⚠️ В торговом квартале произошла кража');
      }
    }
    if (residents.length >= 10 &&
        _random.nextDouble() < .035 &&
        hasFireStation) {
      firesPrevented++;
      events.add('🚒 Пожарные потушили возгорание');
    }
    if (market.food < 2) {
      cityApproval = max(.1, cityApproval - .02);
    }
    for (final r in residents.where((r) => r.criminal)) {
      if (hasPolice || civicBuildings.contains('Полицейский участок')) {
        r.criminal = false;
        crimesResolved++;
        if (civicBuildings.contains('Тюрьма')) r.jailed = 18;
      }
    }
  }

  void _updateCulture(List<ResidentAgent> residents, int objectCount,
      bool hasSchool, List<String> events) {
    final educated = residents.where((r) => r.education > 45).length;
    final healthy = residents.where((r) => r.health > .65).length;
    final eraBonus = eraIndex * 1.5;
    final gain = max(.2, residents.length * .16 + educated * .08 + eraBonus);
    culturePoints += gain;
    heritage += max(0, residents.length * .012 + objectCount * .025);
    final nextLevel = min(10, 1 + (culturePoints / 35).floor());
    if (nextLevel > cultureLevel) {
      cultureLevel = nextLevel;
      tradition = _traditions[(cultureLevel - 1) % _traditions.length];
      for (final r in residents) {
        r.morale = min(1, r.morale + .025);
      }
      prestige += 2;
      events.add('🎭 Культурный расцвет: уровень $cultureLevel — $tradition');
      final monumentLevels = [2, 4, 6, 8, 10];
      if (monumentLevels.contains(cultureLevel)) {
        monuments++;
        events.add('🏛️ Возведён культурный памятник №$monuments');
      }
    }
    dominantCulture = educated > residents.length * .35
        ? 'Образованная городская культура'
        : 'Общие традиции';
    final cohesion = min(.025, cultureLevel * .0008);
    for (final r in residents) {
      r.morale = min(1, r.morale + cohesion);
    }
    if (cultureLevel >= 4 &&
        _random.nextDouble() < .08 &&
        diplomacy.isNotEmpty) {
      final partner =
          diplomacy.keys.elementAt(_random.nextInt(diplomacy.length));
      diplomacy[partner] = min(100, diplomacy[partner]! + .4);
    }
    if (hasSchool && healthy > 0) {
      dominantCulture = 'Образованная городская культура';
    }
  }

  void _updateEra(int population, List<String> events) {
    for (var i = eraIndex + 1; i < eras.length; i++) {
      final era = eras[i];
      if (technologyLevel >= era.$2 && population >= era.$3 && year >= era.$4) {
        eraIndex = i;
        prestige += 5 * i;
        events.add('🚀 Наступила новая эпоха: ${era.$1}');
      } else {
        break;
      }
    }
  }

  void _updateNation(double dt, List<ResidentAgent> residents,
      MarketState market, List<String> events) {
    for (final key in diplomacy.keys.toList()) {
      diplomacy[key] = diplomacy[key]!.clamp(0, 100);
    }
    for (final foreign in foreignNations) {
      final relation = diplomacy[foreign.name];
      if (relation != null) foreign.relation = relation;
    }
    if (army > 0) market.treasury = max(0, market.treasury - dt * army * .002);
  }

  void _ensureHouseholds(
      List<ResidentAgent> residents, List<ResidentSite> sites) {
    final groups = <int, List<ResidentAgent>>{};
    for (final resident in residents) {
      final key = resident.familyId ??
          (resident.spouseId == null
              ? resident.id
              : min(resident.id, resident.spouseId!));
      groups.putIfAbsent(key, () => []).add(resident);
    }
    for (final entry in groups.entries) {
      final members = entry.value;
      var home =
          households.where((item) => item.familyKey == entry.key).firstOrNull;
      if (home == null) {
        var nearestIndex = -1;
        var nearestDistance = double.infinity;
        for (var index = 0; index < sites.length; index++) {
          final site = sites[index];
          if (!_has(site.role.toLowerCase(), ['дом', 'пещера', 'крыша'])) {
            continue;
          }
          for (final member in members) {
            final distance = _distance(site.position.x, site.position.y,
                member.position.x, member.position.y);
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestIndex = index;
            }
          }
        }
        final head = members.first;
        final position =
            nearestIndex >= 0 ? sites[nearestIndex].position : head.position;
        home = HouseholdState(
          id: _nextHomeId++,
          familyKey: entry.key,
          x: position.x,
          y: position.y,
          ownerId: head.id,
          value: (80 + _random.nextInt(101)).toDouble(),
          homeSiteIndex: nearestIndex,
          memberIds: <int>[],
          districtId: head.factionId,
        );
        households.add(home);
      }
      final owner =
          members.where((r) => r.spouseId != null).firstOrNull ?? members.first;
      home.memberIds
        ..clear()
        ..addAll(members.map((r) => r.id));
      home
        ..ownerId = owner.id
        ..level = members.length >= 6
            ? 3
            : members.length >= 4
                ? 2
                : 1
        ..districtId = owner.factionId;
      for (final resident in members) {
        resident
          ..homeId = home.id
          ..homePosition = IsometricPoint(home.x, home.y)
          ..propertyValue = home.value;
      }
    }
    households.removeWhere((home) => !groups.containsKey(home.familyKey));
  }

  void _formFactions(List<ResidentAgent> residents, List<String> events) {
    final free = residents.where((r) => r.factionId == null).toList();
    final visited = <int>{};
    for (final seed in free) {
      if (!visited.add(seed.id)) continue;
      final group = <ResidentAgent>[seed];
      for (var index = 0; index < group.length; index++) {
        final member = group[index];
        for (final candidate in free) {
          if (visited.contains(candidate.id)) continue;
          if (member.friendIds.contains(candidate.id) &&
              _random.nextDouble() < .72) {
            visited.add(candidate.id);
            group.add(candidate);
          }
        }
      }
      if (group.length < 3) continue;
      _createFaction(group, events);
    }
    if (factions.length < 2 || _random.nextDouble() >= .16) return;
    for (var i = 0; i < factions.length - 1; i++) {
      final a = factions[i], b = factions[i + 1];
      if (a.memberIds.length + b.memberIds.length < 6 ||
          _averageAffinity(a, b, residents) <= .28) {
        continue;
      }
      final winner = a.memberIds.length >= b.memberIds.length ? a : b;
      final absorbed = identical(winner, a) ? b : a;
      for (final id in absorbed.memberIds) {
        final resident = _findResident(residents, id);
        if (resident == null) continue;
        resident
          ..factionId = winner.id
          ..morale = min(1, resident.morale + .16);
        if (!winner.memberIds.contains(id)) winner.memberIds.add(id);
      }
      winner
        ..strength = winner.memberIds.length * 10
        ..morale = min(1, (winner.morale + absorbed.morale) / 2 + .08);
      factions.remove(absorbed);
      events.add('🤝 «${winner.name}» объединилась с «${absorbed.name}»');
      break;
    }
  }

  void _createFaction(List<ResidentAgent> members, List<String> events) {
    const names = [
      'Красные дворы',
      'Синие ворота',
      'Зелёная улица',
      'Золотая команда',
      'Северный союз',
      'Старый квартал',
      'Свободные жители',
      'Команда мостика',
    ];
    const colors = [
      0xffe45b55,
      0xff4d9de0,
      0xffe2b84b,
      0xff8c6bd1,
      0xff4fb477,
      0xffdf7db5,
      0xffd58a48,
    ];
    final id = _nextFactionId++;
    final leader = [...members]
      ..sort((a, b) => b.friendIds.length.compareTo(a.friendIds.length));
    final head = leader.first;
    final name =
        names[(id - 1) % names.length] + (id > names.length ? ' $id' : '');
    factions.add(CityFaction(
      id: id,
      name: name,
      color: colors[(id - 1) % colors.length],
      memberIds: members.map((r) => r.id).toList(),
      leaderId: head.id,
      x: head.position.x,
      y: head.position.y,
      strength: members.length * 10,
      morale: .65,
      territory: 75,
      treasury: 24 + members.length * 3,
      food: 18 + members.length * 2,
      materials: (8 + members.length).toDouble(),
      buildings: ['Штаб'],
      district: 'Новый квартал',
    ));
    for (final resident in members) {
      resident
        ..factionId = id
        ..morale = min(1, resident.morale + .12);
    }
    events.add('🎌 Образовалась группировка «$name»');
  }

  void _updateFactions(List<ResidentAgent> residents, List<String> events) {
    const milestones = [
      (5, 'Рынок', 28.0, 8.0),
      (7, 'Мастерская', 42.0, 15.0),
      (8, 'Школа', 65.0, 18.0),
      (10, 'Пожарная часть', 75.0, 22.0),
      (10, 'Пост охраны', 58.0, 20.0),
      (14, 'Общественная площадь', 80.0, 26.0),
      (16, 'Больница', 105.0, 30.0),
      (20, 'Ратуша', 130.0, 38.0),
      (22, 'Колледж', 190.0, 48.0),
      (30, 'Университет', 340.0, 82.0),
      (14, 'Полицейский участок', 120.0, 30.0),
      (18, 'Тюрьма', 150.0, 35.0),
      (22, 'Парк', 90.0, 20.0),
      (26, 'Транспортное депо', 190.0, 45.0),
    ];
    final active = <CityFaction>[];
    for (final faction in factions) {
      faction.memberIds
          .removeWhere((id) => _findResident(residents, id) == null);
      if (faction.memberIds.isEmpty) continue;
      final members =
          faction.memberIds.map((id) => _findResident(residents, id)!).toList();
      final leader =
          _findResident(residents, faction.leaderId) ?? members.first;
      faction
        ..leaderId = leader.id
        ..x = members.fold<double>(0, (sum, r) => sum + r.position.x) /
            members.length
        ..y = members.fold<double>(0, (sum, r) => sum + r.position.y) /
            members.length
        ..strength = members.length * 10 +
            members.fold<int>(0, (sum, r) => sum + r.friendIds.length) * .5
        ..morale =
            members.fold<double>(0, (sum, r) => sum + r.morale) / members.length
        ..territory =
            55 + min(70, members.length * 3) + faction.expansionLevel * 8;
      final workers =
          members.where((r) => r.activity == ResidentActivity.working).length;
      final builders = members.where((r) => r.personality == 'builder').length;
      final income = max(1, workers * 1.4 + members.length * .45);
      faction
        ..treasury = max(0, faction.treasury + income - members.length * .28)
        ..food = max(0,
            faction.food + max(.5, members.length * .22) - members.length * .32)
        ..materials += builders * .65
        ..tradeBalance += income;
      if (faction.food < 2) {
        faction.morale = max(.12, faction.morale - .035);
        for (final resident in members) {
          resident.morale = max(.1, resident.morale - .025);
        }
      } else {
        faction
          ..food = max(0, faction.food - .4)
          ..morale = min(1, faction.morale + .012);
      }
      for (final (count, name, coins, material) in milestones) {
        if (members.length < count || faction.buildings.contains(name)) {
          continue;
        }
        if (faction.treasury < coins || faction.materials < material) continue;
        faction
          ..treasury -= coins
          ..materials -= material
          ..buildings.add(name);
        events.add('🏙️ «${faction.name}» открыла: $name');
      }
      if (faction.treasury > 85 &&
          faction.materials > 30 &&
          faction.expansionLevel < 6 &&
          _random.nextDouble() < .12) {
        faction
          ..treasury -= 35
          ..materials -= 12;
        faction.expansionLevel++;
        events.add('🧭 «${faction.name}» расширила свой район');
      }
      civicBuildings.addAll(faction.buildings);
      active.add(faction);
    }
    factions
      ..clear()
      ..addAll(active);

    for (var i = 0; i < factions.length; i++) {
      for (var j = i + 1; j < factions.length; j++) {
        final a = factions[i], b = factions[j];
        if (a.buildings.contains('Рынок') &&
            b.buildings.contains('Рынок') &&
            _distance(a.x, a.y, b.x, b.y) < 260 &&
            _random.nextDouble() < .3) {
          a.treasury += 5;
          b.treasury += 5;
          a.food = max(0, a.food - 1);
          b.food = max(0, b.food - 1);
          events.add(
              '🪙 Торговля между «${a.name}» и «${b.name}» принесла доход');
        }
      }
    }
  }

  void _resolveFactionConflict(
      List<ResidentAgent> residents, List<String> events) {
    if (factions.length < 2) return;
    for (var i = 0; i < factions.length; i++) {
      final a = factions[i];
      for (var j = i + 1; j < factions.length; j++) {
        final b = factions[j];
        if (_distance(a.x, a.y, b.x, b.y) > (a.territory + b.territory) * .55) {
          continue;
        }
        if (_averageAffinity(a, b, residents) > .2 &&
            _random.nextDouble() < .65) {
          continue;
        }
        final powerA = a.strength *
            (.65 + a.morale * .7) *
            (.85 + _random.nextDouble() * .3);
        final powerB = b.strength *
            (.65 + b.morale * .7) *
            (.85 + _random.nextDouble() * .3);
        final winner = powerA >= powerB ? a : b;
        final loser = identical(winner, a) ? b : a;
        winner.conflictsWon++;
        loser.conflictsLost++;
        winner.morale = min(1, winner.morale + .08);
        loser.morale = max(.15, loser.morale - .12);
        for (final id in loser.memberIds) {
          final resident = _findResident(residents, id);
          if (resident != null) {
            resident.morale = max(.1, resident.morale - .08);
          }
        }
        if (loser.conflictsLost >= 2 &&
            loser.memberIds.length > 3 &&
            _random.nextDouble() < .35) {
          final id = loser.memberIds.removeLast();
          final defector = _findResident(residents, id);
          if (defector != null) {
            defector.factionId = winner.id;
            winner.memberIds.add(id);
          }
        }
        events.add(
            '⚔️ Спор за территорию: «${winner.name}» отстояла границу у «${loser.name}»');
        return;
      }
    }
  }

  double _averageAffinity(
      CityFaction a, CityFaction b, List<ResidentAgent> residents) {
    var total = 0.0;
    var count = 0;
    for (final aid in a.memberIds) {
      final ra = _findResident(residents, aid);
      if (ra == null) continue;
      for (final bid in b.memberIds) {
        final rb = _findResident(residents, bid);
        if (rb == null) continue;
        var affinity = .18;
        if (ra.personality == rb.personality) affinity += .18;
        if (ra.friendIds.contains(rb.id)) affinity += .5;
        if (ra.rivalIds.contains(rb.id)) affinity -= .65;
        total += affinity.clamp(-1, 1);
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  static ResidentAgent? _findResident(List<ResidentAgent> residents, int id) {
    for (final resident in residents) {
      if (resident.id == id) return resident;
    }
    return null;
  }

  static double _distance(double ax, double ay, double bx, double by) =>
      sqrt(pow(ax - bx, 2) + pow(ay - by, 2));

  String? holdFestival(MarketState market, List<ResidentAgent> residents) {
    if (festivalCooldown > 0) return 'Городской праздник пока на перезарядке';
    final cost = 12 + max(0, residents.length - 10) * .4;
    if (market.treasury < cost) {
      return 'Для праздника нужно ${cost.ceil()} монет';
    }
    market.treasury -= cost;
    culturePoints += 12 + residents.length * .25;
    festivals++;
    festivalCooldown = 45;
    for (final r in residents) {
      r.morale = min(1, r.morale + .12);
      r.happiness = min(1, r.happiness + .1);
    }
    prestige += 2;
    tradition = [
      'Праздник урожая',
      'День основания города',
      'Фестиваль ремёсел',
      'Ночь огней',
      'Праздник единства',
    ][festivals % 5];
    return '🎉 $tradition: настроение и культурное влияние растут';
  }

  String recruitArmy(MarketState market) {
    final count = min(5, (market.treasury / 8).floor());
    if (count < 1) return 'Для найма бойцов нужно 8 монет за человека';
    market.treasury -= count * 8;
    army += count;
    return '🛡️ В армию поступило $count бойцов';
  }

  String conductDiplomacy(MarketState market) {
    if (diplomacy.isEmpty) return 'Нет соседних государств';
    if (market.treasury < 12) {
      return 'Для дипломатической миссии нужно 12 монет';
    }
    final partner =
        diplomacy.keys.elementAt(_diplomacyIndex++ % diplomacy.length);
    market.treasury -= 12;
    diplomacy[partner] = min(100, diplomacy[partner]! + 12);
    final foreign = foreignNations.where((state) => state.name == partner).firstOrNull;
    if (foreign != null) foreign.relation = diplomacy[partner]!;
    prestige += 2;
    return diplomacy[partner]! >= 80
        ? '🤝 Заключён союз с державой «$partner»'
        : '🕊️ Отношения с державой «$partner»: ${diplomacy[partner]!.round()}%';
  }

  String launchCampaign(MarketState market, Random? random) {
    final rng = random ?? _random;
    if (army < 3) return 'Для военного похода нужно не менее 3 бойцов';
    if (market.treasury < 20) return 'Для похода нужно 20 монет';
    market.treasury -= 20;
    campaigns++;
    final rival = foreignNations.isEmpty
        ? null
        : foreignNations[rng.nextInt(foreignNations.length)];
    final power = army + technologyLevel * 2 + prestige * .04;
    final difficulty = 6 + territory * .8 + (rival?.army ?? 0) * .12 + rng.nextDouble() * 8;
    if (power >= difficulty) {
      victories++;
      territory++;
      prestige += 8;
      army = max(1, army - 1);
      if (rival != null) {
        rival.territory = max(1, rival.territory - 1);
        rival.army = max(0, rival.army - max(1, (rival.army * .08).ceil()));
        rival.treasury = max(0, rival.treasury - 35);
        rival.relation = max(0, rival.relation - 10);
        diplomacy[rival.name] = rival.relation;
      }
      final reward = 10 + rng.nextInt(16) + min(25, (rival?.treasury ?? 0).floor());
      market.treasury += reward;
      return '🏳️ Победа над державой «${rival?.name ?? 'соседом'}»! Территория расширена, казна получила $reward монет';
    }
    defeats++;
    prestige = max(0, prestige - 3);
    army = max(0, army - max(1, (army * .25).ceil()));
    if (rival != null) {
      rival
        ..army = max(0, rival.army - 1)
        ..relation = max(0, rival.relation - 3);
      diplomacy[rival.name] = rival.relation;
    }
    return '⚔️ Поход против «${rival?.name ?? 'соседа'}» завершился отступлением; армия понесла потери';
  }

  void setTaxRate(MarketState market, double rate) {
    market.taxRate = rate.clamp(0, .5).toDouble();
  }

  void _assignJobs(List<ResidentAgent> residents) {
    for (final r in residents) {
      if (r.age < 18) {
        r.job = 'Малыш';
      } else if (r.age < 42) {
        r.job = 'Ученик';
      } else if (r.age >= 620) {
        r.job = 'Старейшина';
      } else if (r.education >= 82) {
        r.job = r.personality == 'builder' ? 'Инженер' : 'Учёный';
      } else if (r.education >= 58) {
        r.job = r.personality == 'normal'
            ? 'Учитель'
            : r.personality == 'explorer'
                ? 'Врач'
                : 'Специалист';
      } else {
        r.job = switch (r.personality) {
          'builder' => 'Строитель',
          'explorer' => 'Курьер',
          'mystic' => 'Наставник',
          _ => 'Фермер',
        };
      }
    }
  }

  static double _wage(String? job) => switch (job) {
        'Врач' || 'Учитель' || 'Спасатель' => .22,
        _ => .13,
      };

  static bool _has(String value, List<String> parts) =>
      parts.any(value.contains);
}

int _int(Object? value, int fallback) =>
    value is num && value.isFinite ? value.toInt() : fallback;
int? _nullableInt(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;
double _double(Object? value, double fallback) => value is num && value.isFinite
    ? value.toDouble().clamp(0, 1e12).toDouble()
    : fallback;
String _text(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

