import 'dart:math';

import 'resident_simulation.dart';

class MarketState {
  MarketState({
    this.food = 45,
    this.materials = 28,
    this.goods = 18,
    this.tradeVolume = 0,
    this.foodPrice = 2,
    this.materialPrice = 3,
    this.goodsPrice = 4,
    this.treasury = 0,
    this.taxRate = 0.08,
  });

  double food;
  double materials;
  double goods;
  double tradeVolume;
  double foodPrice;
  double materialPrice;
  double goodsPrice;
  double treasury;
  double taxRate;
  double _timer = 0;

  EconomyMetrics get metrics => EconomyMetrics(
        food: food,
        materials: materials,
        goods: goods,
        treasury: treasury,
        taxRate: taxRate,
        tradeVolume: tradeVolume,
      );

  Map<String, dynamic> toJson() => {
        'food': food,
        'materials': materials,
        'goods': goods,
        'tradeVolume': tradeVolume,
        'foodPrice': foodPrice,
        'materialPrice': materialPrice,
        'goodsPrice': goodsPrice,
        'treasury': treasury,
        'taxRate': taxRate,
        'timer': _timer,
      };

  factory MarketState.fromJson(Map<String, dynamic> data) => MarketState(
        food: _read(data, 'food', 45),
        materials: _read(data, 'materials', 28),
        goods: _read(data, 'goods', 18),
        tradeVolume: _read(data, 'tradeVolume', 0),
        foodPrice: _read(data, 'foodPrice', 2),
        materialPrice: _read(data, 'materialPrice', 3),
        goodsPrice: _read(data, 'goodsPrice', 4),
        treasury: _read(data, 'treasury', 0),
        taxRate: _read(data, 'taxRate', .08).clamp(0, .5).toDouble(),
      ).._timer = _read(data, 'timer', 0).clamp(0, 10).toDouble();

  /// Ports updateMarketEconomy() in the HTML source as a ten-second market
  /// step. Site roles supply the starting production and trade buildings.
  List<String> update({
    required double dt,
    required List<ResidentAgent> residents,
    required List<ResidentSite> sites,
    int technologyLevel = 1,
    int eraIndex = 0,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    _timer += dt;
    if (_timer < 10) return const [];
    _timer %= 10;

    _assignJobs(residents);
    final adults = residents.where((r) => r.age >= 42 && r.age < 620).toList();
    final farmers = adults.where((r) => r.job == 'Фермер').length;
    final builders = adults.where((r) => r.job == 'Строитель').length;
    final traders = adults.where((r) => r.job == 'Торговец').length;
    final artisans = adults.where((r) => r.job == 'Ремесленник').length;
    final techBonus = 1 + (technologyLevel - 1) * 0.055 + eraIndex * 0.035;
    final foodMade = (farmers * 1.8 + adults.length * 0.08) * techBonus;
    final materialsMade = builders * 1.15 * techBonus;
    final goodsMade = (artisans * 1.1 + traders * 0.35) * techBonus;
    final foodUsed = residents.length * 0.34;
    food = _clamp(food + foodMade - foodUsed, 0, 9999);
    materials = _clamp(materials + materialsMade, 0, 9999);
    goods = _clamp(goods + goodsMade, 0, 9999);

    final marketBuildings =
        sites.where((s) => s.role == 'рынок' && !s.disabled).length;
    final tradingPower = max(1, traders + marketBuildings * 2);
    var revenue = 0.0;
    if (food > 18) {
      final sold = min(food - 12, tradingPower * 0.7);
      food -= sold;
      revenue += sold * foodPrice;
      tradeVolume += sold;
    }
    if (materials > 12) {
      final sold = min(materials - 8, builders * 0.25 + marketBuildings * 0.7);
      materials -= sold;
      revenue += sold * materialPrice;
      tradeVolume += sold;
    }
    if (goods > 10) {
      final sold = min(goods - 6, tradingPower * 0.5);
      goods -= sold;
      revenue += sold * goodsPrice;
      tradeVolume += sold;
    }

    final taxIncome = adults.fold<double>(
        0, (sum, resident) => sum + resident.wallet * taxRate * 0.006);
    final upkeep = sites.length * 0.12 + residents.length * 0.025;
    treasury = max(0, treasury + revenue * 0.16 + taxIncome - upkeep);

    if (food < 3) {
      for (final resident in residents) {
        resident.happiness = max(0.05, resident.happiness - 0.025);
        resident.morale = max(0.1, resident.morale - 0.015);
      }
      return ['Нехватка продовольствия: запасы и настроение жителей падают'];
    }
    if (food > 25) {
      for (final resident in residents) {
        resident.happiness = min(1, resident.happiness + 0.004);
      }
    }
    if (materials < 2 && builders > 0) {
      return ['Недостаток строительных материалов замедляет развитие'];
    }
    return const [];
  }

  static void _assignJobs(List<ResidentAgent> residents) {
    for (final resident in residents) {
      if (resident.age < 42) {
        resident.job = resident.age < 18 ? 'Малыш' : 'Ученик';
      } else if (resident.age >= 620) {
        resident.job = 'Старейшина';
      } else {
        resident.job = switch (resident.personality) {
          'builder' => 'Строитель',
          'explorer' => 'Торговец',
          'mystic' => 'Ремесленник',
          _ => 'Фермер',
        };
      }
    }
  }

  static double _clamp(double value, double low, double high) =>
      value.clamp(low, high).toDouble();
}

double _read(Map<String, dynamic> map, String key, double fallback) {
  final value = map[key];
  return value is num && value.isFinite
      ? value.toDouble().clamp(0, 1e12).toDouble()
      : fallback;
}

class EconomyMetrics {
  const EconomyMetrics({
    required this.food,
    required this.materials,
    required this.goods,
    required this.treasury,
    required this.taxRate,
    required this.tradeVolume,
  });

  final double food;
  final double materials;
  final double goods;
  final double treasury;
  final double taxRate;
  final double tradeVolume;
}
