import 'dart:math';

import 'resident_simulation.dart';

class MarketState {
  MarketState({
    this.food = 45,
    this.fishStock = 0,
    this.meatStock = 0,
    this.materials = 28,
    this.goods = 18,
    this.tradeVolume = 0,
    this.foodPrice = 2,
    this.materialPrice = 3,
    this.goodsPrice = 4,
    this.treasury = 0,
    this.taxRate = 0.08,
    this.storageCapacity = 250,
    this.foodStorageCapacity = 125,
    this.fishStorageCapacity = 20,
    this.meatStorageCapacity = 20,
    this.materialStorageCapacity = 45,
    this.goodsStorageCapacity = 40,
    this.busTicketFare = .75,
  });

  double food;
  double fishStock;
  double meatStock;
  double materials;
  double goods;
  double tradeVolume;
  double foodPrice;
  double materialPrice;
  double goodsPrice;
  double treasury;
  double taxRate;
  double storageCapacity;
  double foodStorageCapacity;
  double fishStorageCapacity;
  double meatStorageCapacity;
  double materialStorageCapacity;
  double goodsStorageCapacity;
  double busTicketFare;
  double transitRevenue = 0;
  int ticketsSold = 0;
  double fishProduction = 0;
  double meatProduction = 0;
  double _timer = 0;

  double get availableFood => food + fishStock + meatStock;
  double get storedResources =>
      food + fishStock + meatStock + materials + goods;

  EconomyMetrics get metrics => EconomyMetrics(
        food: food,
        fish: fishStock,
        meat: meatStock,
        materials: materials,
        goods: goods,
        treasury: treasury,
        taxRate: taxRate,
        tradeVolume: tradeVolume,
      );

  Map<String, dynamic> toJson() => {
        'food': food,
        'fishStock': fishStock,
        'meatStock': meatStock,
        'materials': materials,
        'goods': goods,
        'tradeVolume': tradeVolume,
        'foodPrice': foodPrice,
        'materialPrice': materialPrice,
        'goodsPrice': goodsPrice,
        'treasury': treasury,
        'taxRate': taxRate,
        'storageCapacity': storageCapacity,
        'foodStorageCapacity': foodStorageCapacity,
        'fishStorageCapacity': fishStorageCapacity,
        'meatStorageCapacity': meatStorageCapacity,
        'materialStorageCapacity': materialStorageCapacity,
        'goodsStorageCapacity': goodsStorageCapacity,
        'busTicketFare': busTicketFare,
        'transitRevenue': transitRevenue,
        'ticketsSold': ticketsSold,
        'fishProduction': fishProduction,
        'meatProduction': meatProduction,
        'timer': _timer,
      };

  factory MarketState.fromJson(Map<String, dynamic> data) => MarketState(
        food: _read(data, 'food', 45),
        fishStock: _read(data, 'fishStock', 0),
        meatStock: _read(data, 'meatStock', 0),
        materials: _read(data, 'materials', 28),
        goods: _read(data, 'goods', 18),
        tradeVolume: _read(data, 'tradeVolume', 0),
        foodPrice: _read(data, 'foodPrice', 2),
        materialPrice: _read(data, 'materialPrice', 3),
        goodsPrice: _read(data, 'goodsPrice', 4),
        treasury: _read(data, 'treasury', 0),
        taxRate: _read(data, 'taxRate', .08).clamp(0, .5).toDouble(),
        storageCapacity: _read(data, 'storageCapacity', 250),
        foodStorageCapacity: _read(data, 'foodStorageCapacity', 125),
        fishStorageCapacity: _read(data, 'fishStorageCapacity', 20),
        meatStorageCapacity: _read(data, 'meatStorageCapacity', 20),
        materialStorageCapacity: _read(data, 'materialStorageCapacity', 45),
        goodsStorageCapacity: _read(data, 'goodsStorageCapacity', 40),
        busTicketFare: _read(data, 'busTicketFare', .75).clamp(0, 3).toDouble(),
      )
        ..fishProduction = _read(data, 'fishProduction', 0)
        ..meatProduction = _read(data, 'meatProduction', 0)
        ..transitRevenue = _read(data, 'transitRevenue', 0)
        ..ticketsSold = _read(data, 'ticketsSold', 0).floor().clamp(0, 1 << 31)
        .._timer = _read(data, 'timer', 0).clamp(0, 10).toDouble();

  bool collectTransitFare(ResidentAgent resident) {
    if (busTicketFare > 0 && resident.wallet < busTicketFare) return false;
    resident.wallet = max(0, resident.wallet - busTicketFare);
    treasury += busTicketFare;
    transitRevenue += busTicketFare;
    ticketsSold++;
    return true;
  }

  /// Ports updateMarketEconomy() in the HTML source as a ten-second market
  /// step. Site roles supply the starting production and trade buildings.
  List<String> update({
    required double dt,
    required List<ResidentAgent> residents,
    required List<ResidentSite> sites,
    int technologyLevel = 1,
    int eraIndex = 0,
    int warehouses = 0,
  }) {
    if (!dt.isFinite || dt < 0) throw ArgumentError.value(dt, 'dt');
    final warehouseCount = max(0, warehouses).toInt();
    foodStorageCapacity = 125 + warehouseCount * 240;
    fishStorageCapacity = 20 + warehouseCount * 50;
    meatStorageCapacity = 20 + warehouseCount * 50;
    materialStorageCapacity = 45 + warehouseCount * 90;
    goodsStorageCapacity = 40 + warehouseCount * 70;
    storageCapacity = foodStorageCapacity +
        fishStorageCapacity +
        meatStorageCapacity +
        materialStorageCapacity +
        goodsStorageCapacity;
    _fitInventoryToCapacity();
    _timer += dt;
    if (_timer < 10) return const [];
    _timer %= 10;

    _assignJobs(residents, sites);
    final adults = residents.where((r) => r.age >= 42 && r.age < 620).toList();
    final farmers = adults.where((r) => r.job == 'Фермер').length;
    final builders = adults.where((r) => r.job == 'Строитель').length;
    final traders = adults.where((r) => r.job == 'Торговец').length;
    final artisans = adults.where((r) => r.job == 'Ремесленник').length;
    final techBonus = 1 + (technologyLevel - 1) * 0.055 + eraIndex * 0.035;
    final fishers = adults.where((r) => r.job == 'Рыбак').length;
    final herders = adults.where((r) => r.job == 'Скотник').length;
    fishProduction = min(fishers,
            sites.where((s) => s.role == 'рыболовство' && !s.disabled).length) *
        .7;
    meatProduction = min(
            herders,
            sites
                .where((s) => s.role == 'животноводство' && !s.disabled)
                .length) *
        .9;
    final foodMade = (farmers * 1.8 + adults.length * 0.08) * techBonus;
    final materialsMade = builders * 1.15 * techBonus;
    final goodsMade = (artisans * 1.1 + traders * 0.35) * techBonus;
    _storeProduction(
      food: foodMade,
      fish: fishProduction * techBonus,
      meat: meatProduction * techBonus,
      materials: materialsMade,
      goods: goodsMade,
    );
    var foodUsed = residents.length * 0.34;
    final eatenFromStaples = min(food, foodUsed);
    food -= eatenFromStaples;
    foodUsed -= eatenFromStaples;
    final eatenFish = min(fishStock, foodUsed);
    fishStock -= eatenFish;
    foodUsed -= eatenFish;
    meatStock = max(0, meatStock - foodUsed);
    final marketBuildings =
        sites.where((s) => s.role == 'рынок' && !s.disabled).length;
    final tradingPower = max(1, traders + marketBuildings * 2);
    var revenue = 0.0;
    if (availableFood > 18) {
      final sold = min(availableFood - 12, tradingPower * 0.7);
      _removeFood(sold);
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

    if (availableFood < 3) {
      for (final resident in residents) {
        resident.happiness = max(0.05, resident.happiness - 0.025);
        resident.morale = max(0.1, resident.morale - 0.015);
      }
      return ['Нехватка продовольствия: запасы и настроение жителей падают'];
    }
    if (availableFood > 25) {
      for (final resident in residents) {
        resident.happiness = min(1, resident.happiness + 0.004);
      }
    }
    if (materials < 2 && builders > 0) {
      return ['Недостаток строительных материалов замедляет развитие'];
    }
    return const [];
  }

  void _removeFood(double amount) {
    var remaining = amount;
    final fromStaples = min(food, remaining);
    food -= fromStaples;
    remaining -= fromStaples;
    final fromFish = min(fishStock, remaining);
    fishStock -= fromFish;
    remaining -= fromFish;
    meatStock = max(0, meatStock - remaining);
  }

  void _storeProduction({
    required double food,
    required double fish,
    required double meat,
    required double materials,
    required double goods,
  }) {
    this.food = min(foodStorageCapacity, this.food + max(0.0, food));
    fishStock = min(fishStorageCapacity, fishStock + max(0.0, fish));
    meatStock = min(meatStorageCapacity, meatStock + max(0.0, meat));
    this.materials =
        min(materialStorageCapacity, this.materials + max(0.0, materials));
    this.goods = min(goodsStorageCapacity, this.goods + max(0.0, goods));
  }

  void _fitInventoryToCapacity() {
    food = min(food, foodStorageCapacity);
    fishStock = min(fishStock, fishStorageCapacity);
    meatStock = min(meatStock, meatStorageCapacity);
    materials = min(materials, materialStorageCapacity);
    goods = min(goods, goodsStorageCapacity);
  }

  static void _assignJobs(
      List<ResidentAgent> residents, List<ResidentSite> sites) {
    for (final resident in residents) {
      if (resident.age < 42) {
        resident.job = resident.age < 18 ? 'Малыш' : 'Ученик';
      } else if (resident.age >= 620) {
        resident.job = 'Старейшина';
      } else if (resident.education >= 82) {
        resident.job = resident.personality == 'builder' ? 'Инженер' : 'Учёный';
      } else if (resident.education >= 58) {
        resident.job = resident.personality == 'normal'
            ? 'Учитель'
            : resident.personality == 'explorer'
                ? 'Врач'
                : 'Специалист';
      } else {
        resident.job = switch (resident.personality) {
          'builder' => 'Строитель',
          'explorer' => 'Торговец',
          'mystic' => 'Ремесленник',
          _ => 'Фермер',
        };
      }
    }
    final available = residents
        .where((r) => r.age >= 42 && r.age < 620 && r.education < 58)
        .toList();
    var workerIndex = 0;
    final fisheryCount =
        sites.where((s) => s.role == 'рыболовство' && !s.disabled).length;
    for (var i = 0; i < fisheryCount && workerIndex < available.length; i++) {
      available[workerIndex++].job = 'Рыбак';
    }
    final livestockCount =
        sites.where((s) => s.role == 'животноводство' && !s.disabled).length;
    for (var i = 0; i < livestockCount && workerIndex < available.length; i++) {
      available[workerIndex++].job = 'Скотник';
    }
  }
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
    required this.fish,
    required this.meat,
    required this.materials,
    required this.goods,
    required this.treasury,
    required this.taxRate,
    required this.tradeVolume,
  });

  final double food;
  final double fish;
  final double meat;
  final double materials;
  final double goods;
  final double treasury;
  final double taxRate;
  final double tradeVolume;
}
