import 'dart:math';

import 'isometric_grid.dart';

enum ResidentActivity { wandering, walkingToSite, working }

class ResidentNeeds {
  ResidentNeeds(
      {required this.hunger, required this.thirst, required this.shelter});

  double hunger;
  double thirst;
  double shelter;

  Map<String, double> toJson() => {
        'hunger': hunger,
        'thirst': thirst,
        'shelter': shelter,
      };
}

class ResidentSite {
  ResidentSite({
    required this.position,
    required this.role,
    this.disabled = false,
  });

  final IsometricPoint position;
  final String role;
  bool disabled;
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
    required this.health,
    this.generation = 0,
    this.familyId,
  });

  final int id;
  IsometricPoint position;
  final String gender;
  double age;
  final String personality;
  final ResidentNeeds needs;
  double morale;
  int wallet;
  double health;
  final int generation;
  int? familyId;
  double birthTimer = 0;
  double education = 0;
  double skill = 0;
  String? job;
  int? homeId;
  int? spouseId;
  final List<int> parentIds = [];
  final List<int> childIds = [];
  final List<int> friendIds = [];
  final List<int> rivalIds = [];
  ResidentActivity activity = ResidentActivity.wandering;
  ResidentSite? target;
  double velocityX = 0;
  double velocityY = 0;
  double thinkTimer = 0;
  double workTimer = 0;
  double walkPhase = 0;
  double happiness = 0.6;
  bool sick = false;
}

class ResidentMetrics {
  const ResidentMetrics({
    required this.population,
    required this.children,
    required this.adults,
    required this.elders,
    required this.couples,
    required this.familyLines,
    required this.generations,
  });

  final int population;
  final int children;
  final int adults;
  final int elders;
  final int couples;
  final int familyLines;
  final int generations;
}

/// Port of the HTML game's independent resident movement and need loop.
/// Family formation and social links are ported as a basic slice; faction,
/// health, job, and market systems remain separate migrations.
class ResidentSimulation {
  ResidentSimulation({
    required this.residents,
    required this.sites,
    required this.width,
    required this.height,
    Random? random,
  }) : _random = random ?? Random();

  factory ResidentSimulation.initial({
    required List<ResidentSite> sites,
    required double width,
    required double height,
    Random? random,
    int residentCount = 8,
  }) {
    final rng = random ?? Random();
    final agents = <ResidentAgent>[];
    const personalities = ['builder', 'explorer', 'mystic', 'normal'];
    for (var i = 0; i < residentCount; i++) {
      agents.add(ResidentAgent(
        id: i + 1,
        position: IsometricPoint(
          (rng.nextDouble() - 0.5) * width * 0.7,
          (rng.nextDouble() - 0.5) * height * 0.7,
        ),
        gender: rng.nextBool() ? 'М' : 'Ж',
        age: 90 + rng.nextDouble() * 260,
        personality: personalities[rng.nextInt(personalities.length)],
        needs: ResidentNeeds(
          hunger: 0.2 + rng.nextDouble() * 0.25,
          thirst: 0.2 + rng.nextDouble() * 0.3,
          shelter: 0.1 + rng.nextDouble() * 0.2,
        ),
        morale: 0.55 + rng.nextDouble() * 0.25,
        wallet: 12 + rng.nextInt(18),
        health: 1,
      ));
    }
    return ResidentSimulation(
      residents: agents,
      sites: sites,
      width: width,
      height: height,
      random: rng,
    );
  }

  final List<ResidentAgent> residents;
  final List<ResidentSite> sites;
  final double width;
  final double height;
  final Random _random;
  double _socialTimer = 0;
  double _familyTimer = 0;
  int _nextId = 1;

  ResidentMetrics get metrics {
    final lineages = residents.map((r) => r.familyId ?? r.id).toSet();
    final maxGeneration = residents.fold<int>(
      0,
      (current, resident) => max(current, resident.generation),
    );
    return ResidentMetrics(
      population: residents.length,
      children: residents.where((r) => r.age < 42).length,
      adults: residents.where((r) => r.age >= 42 && r.age < 620).length,
      elders: residents.where((r) => r.age >= 620).length,
      couples:
          residents.where((r) => r.spouseId != null && r.gender == 'М').length,
      familyLines: lineages.length,
      generations: maxGeneration + 1,
    );
  }

  void _initializeIds() {
    if (residents.isNotEmpty && _nextId == 1) {
      _nextId = residents.map((resident) => resident.id).reduce(max) + 1;
    }
  }

  void update(double dt, {bool isNight = false}) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    _initializeIds();
    for (final resident in residents) {
      _updateResident(resident, dt, isNight: isNight);
    }
    _updateSocialLife(dt);
    _updateFamilies(dt);
  }

  void _updateSocialLife(double dt) {
    _socialTimer += dt;
    if (_socialTimer < 3.5) return;
    _socialTimer = 0;
    for (var i = 0; i < residents.length; i++) {
      final resident = residents[i];
      ResidentAgent? nearest;
      var nearestDistance = 72.0;
      for (var j = 0; j < residents.length; j++) {
        if (i == j) continue;
        final other = residents[j];
        final dx = resident.position.x - other.position.x;
        final dy = resident.position.y - other.position.y;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < nearestDistance) {
          nearest = other;
          nearestDistance = distance;
        }
      }
      final other = nearest;
      if (other == null ||
          resident.friendIds.contains(other.id) ||
          resident.rivalIds.contains(other.id) ||
          _random.nextDouble() >= 0.24) {
        continue;
      }
      final friends = _random.nextDouble() < 0.78;
      final ownLinks = friends ? resident.friendIds : resident.rivalIds;
      final otherLinks = friends ? other.friendIds : other.rivalIds;
      ownLinks.add(other.id);
      otherLinks.add(resident.id);
      final limit = friends ? 8 : 5;
      if (ownLinks.length > limit) ownLinks.removeAt(0);
      if (otherLinks.length > limit) otherLinks.removeAt(0);
    }
  }

  void _updateFamilies(double dt) {
    _familyTimer += dt;
    for (final resident in residents) {
      resident.age += dt;
    }
    if (_familyTimer >= 5) {
      _familyTimer -= 5;
      for (final adult in residents) {
        if (adult.spouseId != null || _lifeStage(adult.age) != 'взрослый') {
          continue;
        }
        ResidentAgent? candidate;
        for (final other in residents) {
          if (adult.friendIds.contains(other.id) &&
              other.spouseId == null &&
              other.gender != adult.gender &&
              _lifeStage(other.age) == 'взрослый' &&
              (adult.familyId == null ||
                  other.familyId == null ||
                  adult.familyId == other.familyId)) {
            candidate = other;
            break;
          }
        }
        if (candidate != null && _random.nextDouble() < 0.12) {
          adult.spouseId = candidate.id;
          candidate.spouseId = adult.id;
          final family = [adult.id, candidate.id].reduce(min);
          adult.familyId = family;
          candidate.familyId = family;
          adult.morale = _clamp(adult.morale + 0.18);
          candidate.morale = _clamp(candidate.morale + 0.18);
        }
      }

      // The source caps household population at 36 for simulation performance.
      final adults = List<ResidentAgent>.of(residents);
      for (final parent in adults) {
        if (parent.spouseId == null ||
            parent.gender != 'Ж' ||
            residents.length >= 36) {
          continue;
        }
        final partner = residents
            .where((resident) => resident.id == parent.spouseId)
            .firstOrNull;
        if (partner == null ||
            parent.age < 75 ||
            parent.age > 480 ||
            !_hasNearbyHome(parent)) {
          continue;
        }
        parent.birthTimer += 5;
        if (parent.birthTimer >= 95 && _random.nextDouble() < 0.45) {
          parent.birthTimer = 0;
          _createChild(parent, partner);
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
      for (final candidate in residents) {
        if (child.parentIds.contains(candidate.id)) {
          parent = candidate;
          break;
        }
      }
      if (parent == null) continue;
      final dx = parent.position.x - child.position.x;
      final dy = parent.position.y - child.position.y;
      if (sqrt(dx * dx + dy * dy) > 75) {
        final factor = min(0.025, dt * 0.012);
        _move(child, dx * factor, dy * factor);
      }
    }
  }

  bool _hasNearbyHome(ResidentAgent resident) => sites.any((site) {
        if (site.disabled ||
            !_matches(
                site.role.toLowerCase(), ['дом', 'пещера', 'крыша', 'склад'])) {
          return false;
        }
        final dx = site.position.x - resident.position.x;
        final dy = site.position.y - resident.position.y;
        return sqrt(dx * dx + dy * dy) < 190;
      });

  void _createChild(ResidentAgent parent, ResidentAgent partner) {
    final inherits = _random.nextDouble() < 0.68;
    final personality = inherits
        ? parent.personality
        : const ['builder', 'explorer', 'mystic', 'normal'][_random.nextInt(4)];
    final id = _nextId++;
    final family =
        parent.familyId ?? partner.familyId ?? min(parent.id, partner.id);
    residents.add(ResidentAgent(
      id: id,
      position: IsometricPoint(
        (parent.position.x + partner.position.x) / 2,
        (parent.position.y + partner.position.y) / 2,
      ),
      gender: _random.nextBool() ? 'М' : 'Ж',
      age: 0,
      personality: personality,
      needs: ResidentNeeds(hunger: 0.15, thirst: 0.15, shelter: 0.1),
      morale: 0.8,
      wallet: 0,
      health: 1,
      generation: max(parent.generation, partner.generation) + 1,
      familyId: family,
    )
      ..parentIds.addAll([parent.id, partner.id])
      ..skill = (parent.skill + partner.skill) * 0.04
      ..education = (parent.education + partner.education) * 0.06);
    parent.childIds.add(id);
    partner.childIds.add(id);
  }

  static String _lifeStage(double age) {
    if (age < 18) return 'малыш';
    if (age < 42) return 'ребёнок';
    if (age < 72) return 'подросток';
    if (age < 620) return 'взрослый';
    return 'старейшина';
  }

  void _updateResident(ResidentAgent resident, double dt,
      {required bool isNight}) {
    final shelterRate = isNight ? 0.0136 : 0.008;
    resident.needs.hunger = _clamp(resident.needs.hunger + 0.012 * dt);
    resident.needs.thirst = _clamp(resident.needs.thirst + 0.018 * dt);
    resident.needs.shelter = _clamp(resident.needs.shelter + shelterRate * dt);

    switch (resident.activity) {
      case ResidentActivity.wandering:
        resident.thinkTimer -= dt;
        if (resident.thinkTimer <= 0) {
          resident.thinkTimer = 0.8 + _random.nextDouble();
          resident.target = _findBestTarget(resident);
          if (resident.target != null) {
            resident.activity = ResidentActivity.walkingToSite;
          }
        }
        if (_random.nextDouble() < 0.03) {
          resident.velocityX = (_random.nextDouble() - 0.5) * 22;
          resident.velocityY = (_random.nextDouble() - 0.5) * 22;
        }
        resident.velocityX *= 0.96;
        resident.velocityY *= 0.96;
        _move(resident, resident.velocityX * dt, resident.velocityY * dt);
      case ResidentActivity.walkingToSite:
        final target = resident.target;
        if (target == null || target.disabled) {
          resident.target = null;
          resident.activity = ResidentActivity.wandering;
          break;
        }
        final dx = target.position.x - resident.position.x;
        final dy = target.position.y - resident.position.y;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < 18) {
          resident.activity = ResidentActivity.working;
          resident.workTimer = 2 + _random.nextDouble() * 3;
          target.users++;
          resident.velocityX = 0;
          resident.velocityY = 0;
        } else {
          _move(resident, dx / distance * 55 * dt, dy / distance * 55 * dt);
        }
      case ResidentActivity.working:
        resident.workTimer -= dt;
        _move(
          resident,
          (_random.nextDouble() - 0.5) * 6 * dt,
          (_random.nextDouble() - 0.5) * 6 * dt,
        );
        final target = resident.target;
        if (resident.workTimer <= 0 || target == null || target.disabled) {
          if (target != null) {
            _satisfyNeed(resident.needs, target.role);
            target.users = max(0, target.users - 1);
          }
          resident.target = null;
          resident.activity = ResidentActivity.wandering;
          resident.thinkTimer = 0.4 + _random.nextDouble() * 0.6;
        }
    }

    if (resident.activity == ResidentActivity.walkingToSite ||
        resident.velocityX.abs() + resident.velocityY.abs() > 3) {
      resident.walkPhase += dt * 16;
    } else {
      resident.walkPhase *= 0.9;
    }
  }

  ResidentSite? _findBestTarget(ResidentAgent resident) {
    ResidentSite? best;
    var bestScore = -double.infinity;
    for (final site in sites) {
      if (site.disabled) continue;
      final dx = resident.position.x - site.position.x;
      final dy = resident.position.y - site.position.y;
      final distance = sqrt(dx * dx + dy * dy);
      final role = site.role.toLowerCase();
      var roleBonus = 0.0;
      if (role.contains('дом') || role.contains('пещера')) {
        roleBonus = 3.2;
      } else if (role.contains('вода') || role.contains('источник')) {
        roleBonus = 2.8;
      } else if (role.contains('парк') || role.contains('площадь')) {
        roleBonus = 2.0;
      }
      var need = 0.0;
      if (_matches(role, ['ферма', 'склад', 'рынок', 'дерево'])) {
        need += resident.needs.hunger * 1.4;
      }
      if (_matches(role, ['вода', 'источник', 'колодец'])) {
        need += resident.needs.thirst * 1.8;
      }
      if (_matches(role, ['дом', 'пещера', 'крыша'])) {
        need += resident.needs.shelter * 1.6;
      }
      final preference = _personalityMultiplier(resident.personality, role);
      final score =
          (20 - distance * 0.08 - site.users * 1.4 + roleBonus + need * 11) *
                  preference +
              _random.nextDouble() * 2.2;
      if (score > bestScore) {
        bestScore = score;
        best = site;
      }
    }
    return best;
  }

  void _move(ResidentAgent resident, double dx, double dy) {
    resident.position = IsometricPoint(
      (resident.position.x + dx).clamp(-width / 2, width / 2).toDouble(),
      (resident.position.y + dy).clamp(-height / 2, height / 2).toDouble(),
    );
  }

  static void _satisfyNeed(ResidentNeeds needs, String role) {
    final value = role.toLowerCase();
    if (_matches(value, ['ферма', 'склад', 'рынок', 'дерево'])) {
      needs.hunger = max(0, needs.hunger - 0.55);
    }
    if (_matches(value, ['вода', 'источник', 'колодец'])) {
      needs.thirst = max(0, needs.thirst - 0.7);
    }
    if (_matches(value, ['дом', 'пещера', 'крыша'])) {
      needs.shelter = max(0, needs.shelter - 0.6);
    }
  }

  static bool _matches(String value, List<String> terms) =>
      terms.any(value.contains);

  static double _personalityMultiplier(String personality, String role) {
    final preferences = switch (personality) {
      'builder' => ['дом', 'пещера', 'крыша', 'склад', 'ферма'],
      'explorer' => ['мост', 'тропа', 'скала', 'парк'],
      'mystic' => ['алтарь', 'озеро', 'источник', 'площадь'],
      _ => const <String>[],
    };
    if (preferences.isEmpty) return 1;
    return preferences.any(role.contains) ? 2.1 : 0.85;
  }

  static double _clamp(double value) => value.clamp(0, 1).toDouble();
}
