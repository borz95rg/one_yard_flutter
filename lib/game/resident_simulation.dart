import 'dart:math';

import 'isometric_grid.dart';

enum ResidentActivity { wandering, walking, working, atHome }

class ResidentNeeds {
  ResidentNeeds(this.hunger, this.thirst, this.shelter);
  double hunger;
  double thirst;
  double shelter;

  Map<String, double> toJson() => {
        'hunger': hunger,
        'thirst': thirst,
        'shelter': shelter,
      };

  factory ResidentNeeds.fromJson(Object? source) {
    final data = source is Map ? source : const <String, Object?>{};
    return ResidentNeeds(
      _number(data['hunger'], .2),
      _number(data['thirst'], .2),
      _number(data['shelter'], .1),
    );
  }
}

class ResidentSite {
  ResidentSite(this.position, this.role);
  final IsometricPoint position;
  final String role;
  bool disabled = false;
  int users = 0;
}

class ResidentAgent {
  ResidentAgent({
    required this.id,
    required this.position,
    required this.gender,
    required this.age,
    required this.personality,
    required this.needs,
    required this.morale,
    required this.wallet,
    this.name = 'Житель',
    this.generation = 0,
    this.familyId,
  });

  final int id;
  final String name;
  IsometricPoint position;
  final String gender;
  double age;
  final String personality;
  final ResidentNeeds needs;
  double morale;
  double wallet;
  final int generation;
  int? familyId;
  int? factionId;
  int? spouseId;
  double birthTimer = 0;
  double workTimer = 0;
  double thinkTimer = 0;
  double velocityX = 0;
  double velocityY = 0;
  double walkPhase = 0;
  double happiness = 0.6;
  double health = 1;
  double immunity = .15;
  String? illness;
  bool sick = false;
  bool criminal = false;
  double jailed = 0;
  int? homeId;
  IsometricPoint? homePosition;
  double propertyValue = 0;
  bool isChief = false;
  double education = 0;
  double skill = 0;
  String? job;
  ResidentActivity activity = ResidentActivity.wandering;
  ResidentSite? target;
  ResidentSite? workSite;
  bool onShift = false;
  bool travelingToWork = false;
  bool returningHome = false;
  final friendIds = <int>[];
  final rivalIds = <int>[];
  final parentIds = <int>[];
  final childIds = <int>[];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': position.x,
        'y': position.y,
        'gender': gender,
        'age': age,
        'personality': personality,
        'needs': needs.toJson(),
        'morale': morale,
        'wallet': wallet,
        'generation': generation,
        'familyId': familyId,
        'factionId': factionId,
        'spouseId': spouseId,
        'birthTimer': birthTimer,
        'happiness': happiness,
        'health': health,
        'immunity': immunity,
        'illness': illness,
        'sick': sick,
        'criminal': criminal,
        'jailed': jailed,
        'homeId': homeId,
        'homeX': homePosition?.x,
        'homeY': homePosition?.y,
        'propertyValue': propertyValue,
        'isChief': isChief,
        'education': education,
        'skill': skill,
        'job': job,
        'friendIds': friendIds,
        'rivalIds': rivalIds,
        'parentIds': parentIds,
        'childIds': childIds,
      };

  factory ResidentAgent.fromJson(Map<String, dynamic> data) {
    final personalityData = data['personality'];
    final personality = personalityData is Map
        ? '${personalityData['id'] ?? 'normal'}'
        : '${personalityData ?? 'normal'}';
    final agent = ResidentAgent(
      id: _integer(data['id'], 0),
      name: data['name'] is String ? data['name'] as String : 'Житель',
      position: IsometricPoint(_number(data['x'], 0), _number(data['y'], 0)),
      gender: data['gender'] == 'Ж' ? 'Ж' : 'М',
      age: _number(data['age'], 90),
      personality: personality,
      needs: ResidentNeeds.fromJson(data['needs']),
      morale: _number(data['morale'], .65),
      wallet: _number(data['wallet'], 12),
      generation: _integer(data['generation'], 0),
      familyId: _optionalInteger(data['familyId']),
    )
      ..spouseId = _optionalInteger(data['spouseId'])
      ..factionId = _optionalInteger(data['factionId'])
      ..birthTimer = _number(data['birthTimer'], 0)
      ..happiness = _number(data['happiness'], .6)
      ..health = _number(data['health'], 1)
      ..immunity = _number(data['immunity'], .15).clamp(0, .95).toDouble()
      ..illness = data['illness'] is String ? data['illness'] as String : null
      ..sick = data['sick'] == true
      ..criminal = data['criminal'] == true
      ..jailed = _number(data['jailed'], 0)
      ..homeId = _optionalInteger(data['homeId'])
      ..homePosition = data['homeX'] is num && data['homeY'] is num
          ? IsometricPoint(
              (data['homeX'] as num).toDouble(),
              (data['homeY'] as num).toDouble(),
            )
          : null
      ..propertyValue = _number(data['propertyValue'], 0)
      ..isChief = data['isChief'] == true
      ..education = _number(data['education'], 0)
      ..skill = _number(data['skill'], 0)
      ..job = data['job'] is String ? data['job'] as String : null;
    agent.friendIds.addAll(_integerList(data['friendIds']));
    agent.rivalIds.addAll(_integerList(data['rivalIds']));
    agent.parentIds.addAll(_integerList(data['parentIds']));
    agent.childIds.addAll(_integerList(data['childIds']));
    return agent;
  }
}

class ResidentMetrics {
  const ResidentMetrics(
      {required this.population,
      required this.children,
      required this.adults,
      required this.elders,
      required this.couples,
      required this.familyLines,
      required this.generations});
  final int population,
      children,
      adults,
      elders,
      couples,
      familyLines,
      generations;
}

/// Initial port of updateResident(), updateSocialLife() and updateFamilies()
/// from the supplied HTML source. Higher-level faction and health rules remain
/// separate systems.
class ResidentSimulation {
  ResidentSimulation._(
      this.residents, this.sites, this.width, this.height, this._rng);

  factory ResidentSimulation.initial({
    required List<ResidentSite> sites,
    required double width,
    required double height,
    Random? random,
    int count = 8,
  }) {
    final rng = random ?? Random();
    const personalities = ['builder', 'explorer', 'mystic', 'normal'];
    const names = [
      'Алан',
      'Айша',
      'Бек',
      'Дана',
      'Ерлан',
      'Жания',
      'Илья',
      'Мира',
      'Нур',
      'Олег',
      'Рая',
      'Саян'
    ];
    final people = List.generate(
        count,
        (i) => ResidentAgent(
              id: i + 1,
              name: names[i % names.length],
              position: IsometricPoint((rng.nextDouble() - .5) * width * .7,
                  (rng.nextDouble() - .5) * height * .7),
              gender: rng.nextBool() ? 'М' : 'Ж',
              age: 90 + rng.nextDouble() * 260,
              personality: personalities[rng.nextInt(personalities.length)],
              needs: ResidentNeeds(.2 + rng.nextDouble() * .25,
                  .2 + rng.nextDouble() * .3, .1 + rng.nextDouble() * .2),
              morale: .55 + rng.nextDouble() * .25,
              wallet: (12 + rng.nextInt(18)).toDouble(),
            ));
    return ResidentSimulation._(people, sites, width, height, rng);
  }

  factory ResidentSimulation.restore({
    required Object? source,
    required List<ResidentSite> sites,
    required double width,
    required double height,
  }) {
    final data = source is List ? source : const [];
    final people = data
        .whereType<Map>()
        .map(
            (entry) => ResidentAgent.fromJson(Map<String, dynamic>.from(entry)))
        .where((resident) => resident.id > 0)
        .toList();
    final simulation =
        ResidentSimulation._(people, sites, width, height, Random());
    if (people.isNotEmpty) {
      simulation._nextId = people.map((r) => r.id).reduce(max) + 1;
    }
    return simulation;
  }

  factory ResidentSimulation.fromLegacySave({
    required Object? source,
    required List<ResidentSite> sites,
    required double width,
    required double height,
  }) {
    final saved = source is List ? source.whereType<Map>().toList() : <Map>[];
    final rng = Random();
    final traits = ['builder', 'explorer', 'mystic', 'normal'];
    final people = <ResidentAgent>[];
    for (var index = 0; index < saved.length; index++) {
      final data = Map<String, dynamic>.from(saved[index]);
      final personality = '${data['personalityId'] ?? 'normal'}';
      people.add(ResidentAgent(
        id: _integer(data['id'], index + 1),
        name: data['name'] is String
            ? data['name'] as String
            : 'Житель ${index + 1}',
        position: IsometricPoint((rng.nextDouble() - .5) * width * .6,
            (rng.nextDouble() - .5) * height * .6),
        gender: data['gender'] == 'Ж' ? 'Ж' : 'М',
        age: _number(data['age'], 90 + rng.nextDouble() * 260),
        personality: traits.contains(personality) ? personality : 'normal',
        needs: ResidentNeeds(.2 + rng.nextDouble() * .25,
            .2 + rng.nextDouble() * .3, .1 + rng.nextDouble() * .2),
        morale: _number(data['morale'], .65),
        wallet: _number(data['wallet'], 12),
        generation: _integer(data['generation'], 0),
        familyId: _optionalInteger(data['familyId']),
      )
        ..spouseId = _optionalInteger(data['spouseId'])
        ..factionId = _optionalInteger(data['factionId'])
        ..birthTimer = _number(data['birthTimer'], 0)
        ..happiness = _number(data['happiness'], .6)
        ..health = _number(data['health'], 1)
        ..immunity = _number(data['immunity'], .15).clamp(0, .95).toDouble()
        ..illness = data['illness'] is String ? data['illness'] as String : null
        ..sick = data['sick'] == true
        ..criminal = data['criminal'] == true
        ..jailed = _number(data['jailed'], 0)
        ..homeId = _optionalInteger(data['homeId'])
        ..propertyValue = _number(data['propertyValue'], 0)
        ..isChief = data['isChief'] == true
        ..education = _number(data['education'], 0)
        ..skill = _number(data['skill'], 0)
        ..job = data['job'] is String ? data['job'] as String : null
        ..friendIds.addAll(_integerList(data['friendIds']))
        ..rivalIds.addAll(_integerList(data['rivalIds']))
        ..parentIds.addAll(_integerList(data['parentIds']))
        ..childIds.addAll(_integerList(data['childIds'])));
    }
    final simulation = ResidentSimulation._(people, sites, width, height, rng);
    if (people.isNotEmpty) {
      simulation._nextId = people.map((r) => r.id).reduce(max) + 1;
    }
    return simulation;
  }

  final List<ResidentAgent> residents;
  final List<ResidentSite> sites;
  final double width, height;
  final Random _rng;
  double _socialTimer = 0, _familyTimer = 0;
  int _nextId = 9;

  ResidentMetrics get metrics {
    final familyIds = residents.map((r) => r.familyId ?? r.id).toSet();
    final highestGeneration =
        residents.fold<int>(0, (v, r) => max(v, r.generation));
    return ResidentMetrics(
      population: residents.length,
      children: residents.where((r) => r.age < 42).length,
      adults: residents.where((r) => r.age >= 42 && r.age < 620).length,
      elders: residents.where((r) => r.age >= 620).length,
      couples:
          residents.where((r) => r.spouseId != null && r.gender == 'М').length,
      familyLines: familyIds.length,
      generations: highestGeneration + 1,
    );
  }

  List<Map<String, dynamic>> toJson() =>
      residents.map((resident) => resident.toJson()).toList(growable: false);

  void update(double dt, {bool isNight = false, int hour = 12}) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final shiftHours = hour >= 8 && hour < 18;
    for (final r in residents) {
      r.needs.hunger = _clamp(r.needs.hunger + .012 * dt);
      r.needs.thirst = _clamp(r.needs.thirst + .018 * dt);
      r.needs.shelter =
          _clamp(r.needs.shelter + .008 * (isNight ? 1.7 : 1) * dt);
      final workingAge = r.age >= 42 && r.age < 620;
      final hasJob = workingAge &&
          r.job != null &&
          !const ['Ученик', 'Малыш', 'Старейшина'].contains(r.job);
      if (hasJob && shiftHours && !r.onShift && !r.travelingToWork) {
        if (r.activity == ResidentActivity.atHome ||
            (r.activity == ResidentActivity.wandering && r.target == null)) {
          final workplace = _findWorkplace(r);
          if (workplace != null) {
            r
              ..workSite = workplace
              ..target = workplace
              ..activity = ResidentActivity.walking
              ..travelingToWork = true
              ..returningHome = false;
          }
        }
      } else if ((!shiftHours || !hasJob) &&
          (r.onShift || r.travelingToWork)) {
        _startJourneyHome(r);
      }
      switch (r.activity) {
        case ResidentActivity.wandering:
          r.thinkTimer -= dt;
          if (r.thinkTimer <= 0) {
            r.thinkTimer = .8 + _rng.nextDouble();
            r.target = _findTarget(r);
            if (r.target != null) r.activity = ResidentActivity.walking;
          }
          if (_rng.nextDouble() < .03) {
            r.velocityX = (_rng.nextDouble() - .5) * 22;
            r.velocityY = (_rng.nextDouble() - .5) * 22;
          }
          r.velocityX *= .96;
          r.velocityY *= .96;
          _move(r, r.velocityX * dt, r.velocityY * dt);
        case ResidentActivity.walking:
          final site = r.target;
          if (site == null || site.disabled) {
            r.target = null;
            r.activity = ResidentActivity.wandering;
            break;
          }
          final dx = site.position.x - r.position.x;
          final dy = site.position.y - r.position.y;
          final distance = sqrt(dx * dx + dy * dy);
          if (distance < 18) {
            if (r.returningHome) {
              r
                ..activity = ResidentActivity.atHome
                ..target = null
                ..returningHome = false;
            } else if (r.travelingToWork) {
              r
                ..activity = ResidentActivity.working
                ..travelingToWork = false
                ..onShift = true;
              site.users++;
            } else {
              r.activity = ResidentActivity.working;
              r.workTimer = 2 + _rng.nextDouble() * 3;
              site.users++;
            }
          } else {
            _move(r, dx / distance * 55 * dt, dy / distance * 55 * dt);
          }
        case ResidentActivity.working:
          if (r.onShift) break;
          r.workTimer -= dt;
          final site = r.target;
          if (r.workTimer <= 0 || site == null || site.disabled) {
            if (site != null) {
              _satisfy(r.needs, site.role);
              site.users = max(0, site.users - 1);
            }
            r.target = null;
            r.activity = ResidentActivity.wandering;
            r.thinkTimer = .4 + _rng.nextDouble() * .6;
          }
        case ResidentActivity.atHome:
          break;
      }
      r.walkPhase = r.activity == ResidentActivity.walking
          ? r.walkPhase + dt * 16
          : r.walkPhase * .9;
    }
    _updateSocial(dt);
    _updateFamilies(dt);
  }

  ResidentSite? _findTarget(ResidentAgent r) {
    ResidentSite? best;
    var bestScore = -double.infinity;
    for (final site in sites) {
      if (site.disabled) continue;
      final role = site.role.toLowerCase();
      final dx = r.position.x - site.position.x,
          dy = r.position.y - site.position.y;
      final distance = sqrt(dx * dx + dy * dy);
      var need = 0.0, bonus = 0.0;
      if (_has(role, ['ферма', 'склад', 'рынок', 'дерево'])) {
        need += r.needs.hunger * 1.4;
      }
      if (_has(role, ['вода', 'источник', 'колодец'])) {
        need += r.needs.thirst * 1.8;
      }
      if (_has(role, ['дом', 'пещера', 'крыша'])) {
        need += r.needs.shelter * 1.6;
      }
      if (_has(role, ['дом', 'пещера'])) {
        bonus = 3.2;
      }
      if (_has(role, ['вода', 'источник'])) {
        bonus = 2.8;
      }
      final pref = _preference(r.personality, role);
      final score =
          (20 - distance * .08 - site.users * 1.4 + bonus + need * 11) * pref +
              _rng.nextDouble() * 2.2;
      if (score > bestScore) {
        bestScore = score;
        best = site;
      }
    }
    return best;
  }

  ResidentSite? _findWorkplace(ResidentAgent resident) {
    final job = resident.job?.toLowerCase() ?? '';
    final preferred = switch (job) {
      'фермер' => const ['ферма', 'склад'],
      'строитель' || 'инженер' => const ['производство', 'мастерская', 'дорога', 'совет'],
      'торговец' || 'курьер' => const ['рынок', 'торговля'],
      'врач' || 'спасатель' => const ['больница', 'медпункт', 'клиника'],
      'учитель' || 'учёный' || 'ученый' => const ['школа', 'университет', 'колледж', 'совет'],
      'ремесленник' || 'специалист' || 'наставник' => const ['мастерская', 'рынок', 'совет', 'ферма'],
      _ => const <String>[],
    };
    if (preferred.isEmpty) return null;
    ResidentSite? best;
    var bestScore = double.infinity;
    for (final site in sites) {
      if (site.disabled || !_has(site.role.toLowerCase(), preferred)) continue;
      final dx = resident.position.x - site.position.x;
      final dy = resident.position.y - site.position.y;
      final score = sqrt(dx * dx + dy * dy) + site.users * 28;
      if (score < bestScore) {
        best = site;
        bestScore = score;
      }
    }
    return best;
  }

  void _startJourneyHome(ResidentAgent resident) {
    if (resident.activity == ResidentActivity.working && resident.onShift) {
      final workplace = resident.target;
      if (workplace != null) workplace.users = max(0, workplace.users - 1);
    }
    resident
      ..onShift = false
      ..travelingToWork = false
      ..workSite = null;
    final home = resident.homePosition;
    if (home == null) {
      resident
        ..target = null
        ..activity = ResidentActivity.wandering
        ..returningHome = false;
      return;
    }
    resident
      ..target = ResidentSite(home, 'дом')
      ..activity = ResidentActivity.walking
      ..returningHome = true;
  }

  void _updateSocial(double dt) {
    _socialTimer += dt;
    if (_socialTimer < 3.5) return;
    _socialTimer = 0;
    for (var i = 0; i < residents.length; i++) {
      final a = residents[i];
      ResidentAgent? nearest;
      var nearestDistance = 72.0;
      for (var j = 0; j < residents.length; j++) {
        if (i == j) continue;
        final b = residents[j];
        final dx = a.position.x - b.position.x,
            dy = a.position.y - b.position.y;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < nearestDistance) {
          nearest = b;
          nearestDistance = distance;
        }
      }
      final b = nearest;
      if (b == null ||
          a.friendIds.contains(b.id) ||
          a.rivalIds.contains(b.id) ||
          _rng.nextDouble() >= .24) {
        continue;
      }
      final friends = _rng.nextDouble() < .78;
      final left = friends ? a.friendIds : a.rivalIds;
      final right = friends ? b.friendIds : b.rivalIds;
      left.add(b.id);
      right.add(a.id);
      final maxLinks = friends ? 8 : 5;
      if (left.length > maxLinks) left.removeAt(0);
      if (right.length > maxLinks) right.removeAt(0);
    }
  }

  void _updateFamilies(double dt) {
    _familyTimer += dt;
    for (final r in residents) {
      r.age += dt;
    }
    if (_familyTimer >= 5) {
      _familyTimer -= 5;
      for (final a in List<ResidentAgent>.of(residents)) {
        if (a.spouseId != null || _lifeStage(a.age) != 'взрослый') continue;
        ResidentAgent? partner;
        for (final b in residents) {
          if (a.friendIds.contains(b.id) &&
              b.spouseId == null &&
              b.gender != a.gender &&
              _lifeStage(b.age) == 'взрослый' &&
              (a.familyId == null ||
                  b.familyId == null ||
                  a.familyId == b.familyId)) {
            partner = b;
            break;
          }
        }
        if (partner != null && _rng.nextDouble() < .12) {
          a.spouseId = partner.id;
          partner.spouseId = a.id;
          final family = min(a.id, partner.id);
          a.familyId = family;
          partner.familyId = family;
          a.morale = _clamp(a.morale + .18);
          partner.morale = _clamp(partner.morale + .18);
        }
      }
      for (final mother in List<ResidentAgent>.of(residents)) {
        if (mother.spouseId == null ||
            mother.gender != 'Ж' ||
            residents.length >= 36 ||
            mother.age < 75 ||
            mother.age > 480 ||
            !_hasNearbyHome(mother)) {
          continue;
        }
        final spouseId = mother.spouseId;
        if (spouseId == null) continue;
        final partner = _byId(spouseId);
        if (partner == null) {
          continue;
        }
        mother.birthTimer += 5;
        if (mother.birthTimer >= 95 && _rng.nextDouble() < .45) {
          mother.birthTimer = 0;
          _createChild(mother, partner);
        }
      }
    }
    for (final child in residents) {
      if (child.age >= 42 ||
          child.parentIds.isEmpty ||
          child.activity == ResidentActivity.working) {
        continue;
      }
      ResidentAgent? parent;
      for (final resident in residents) {
        if (child.parentIds.contains(resident.id)) {
          parent = resident;
          break;
        }
      }
      if (parent == null) continue;
      final dx = parent.position.x - child.position.x,
          dy = parent.position.y - child.position.y;
      if (sqrt(dx * dx + dy * dy) > 75) {
        _move(child, dx * min(.025, dt * .012), dy * min(.025, dt * .012));
      }
    }
  }

  void _createChild(ResidentAgent a, ResidentAgent b) {
    final traits = ['builder', 'explorer', 'mystic', 'normal'];
    final personality = _rng.nextDouble() < .68
        ? a.personality
        : traits[_rng.nextInt(traits.length)];
    final id = _nextId++;
    const childNames = [
      'Алия',
      'Арман',
      'Баян',
      'Дамир',
      'Ева',
      'Марат',
      'Самира'
    ];
    final child = ResidentAgent(
      id: id,
      name: childNames[_rng.nextInt(childNames.length)],
      position: IsometricPoint(
          (a.position.x + b.position.x) / 2, (a.position.y + b.position.y) / 2),
      gender: _rng.nextBool() ? 'М' : 'Ж',
      age: 0,
      personality: personality,
      needs: ResidentNeeds(.15, .15, .1),
      morale: .8,
      wallet: 0,
      generation: max(a.generation, b.generation) + 1,
      familyId: a.familyId ?? b.familyId ?? min(a.id, b.id),
    )..parentIds.addAll([a.id, b.id]);
    child.skill = (a.skill + b.skill) * .04;
    child.education = (a.education + b.education) * .06;
    residents.add(child);
    a.childIds.add(id);
    b.childIds.add(id);
  }

  bool _hasNearbyHome(ResidentAgent r) => sites.any((s) {
        if (s.disabled ||
            !_has(s.role.toLowerCase(), ['дом', 'пещера', 'крыша', 'склад'])) {
          return false;
        }
        final dx = s.position.x - r.position.x,
            dy = s.position.y - r.position.y;
        return sqrt(dx * dx + dy * dy) < 190;
      });

  ResidentAgent? _byId(int id) {
    for (final resident in residents) {
      if (resident.id == id) return resident;
    }
    return null;
  }

  void _move(ResidentAgent r, double dx, double dy) {
    r.position = IsometricPoint(
      (r.position.x + dx).clamp(-width / 2, width / 2).toDouble(),
      (r.position.y + dy).clamp(-height / 2, height / 2).toDouble(),
    );
  }

  static void _satisfy(ResidentNeeds n, String role) {
    final value = role.toLowerCase();
    if (_has(value, ['ферма', 'склад', 'рынок', 'дерево'])) {
      n.hunger = max(0, n.hunger - .55);
    }
    if (_has(value, ['вода', 'источник', 'колодец'])) {
      n.thirst = max(0, n.thirst - .7);
    }
    if (_has(value, ['дом', 'пещера', 'крыша'])) {
      n.shelter = max(0, n.shelter - .6);
    }
  }

  static String _lifeStage(double age) => age < 18
      ? 'малыш'
      : age < 42
          ? 'ребёнок'
          : age < 72
              ? 'подросток'
              : age < 620
                  ? 'взрослый'
                  : 'старейшина';
  static bool _has(String value, List<String> terms) =>
      terms.any(value.contains);
  static double _clamp(double x) => x.clamp(0, 1).toDouble();
  static double _preference(String personality, String role) {
    final terms = switch (personality) {
      'builder' => ['дом', 'пещера', 'крыша', 'склад', 'ферма'],
      'explorer' => ['мост', 'тропа', 'скала', 'парк'],
      'mystic' => ['алтарь', 'озеро', 'источник', 'площадь'],
      _ => const <String>[],
    };
    return terms.isEmpty
        ? 1
        : terms.any(role.contains)
            ? 2.1
            : .85;
  }
}

double _number(Object? value, double fallback) => value is num && value.isFinite
    ? value.toDouble().clamp(0, 1e9).toDouble()
    : fallback;

int _integer(Object? value, int fallback) =>
    value is num && value.isFinite ? value.toInt() : fallback;

int? _optionalInteger(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

List<int> _integerList(Object? value) => value is List
    ? value.whereType<num>().map((number) => number.toInt()).toList()
    : const [];

