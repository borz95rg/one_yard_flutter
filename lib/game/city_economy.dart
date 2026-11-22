import 'dart:math';

import 'resident_simulation.dart';

enum StoredResource { food, fish, meat, materials, goods }

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
    this.foodStorageCapacity = 120,
    this.fishStorageCapacity = 25,
    this.meatStorageCapacity = 25,
    this.materialStorageCapacity = 45,
    this.goodsStorageCapacity = 35,
    this.foodStorageShare = .48,
    this.fishStorageShare = .1,
    this.meatStorageShare = .1,
    this.materialStorageShare = .18,
    this.goodsStorageShare = .14,
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
  double foodStorageShare;
  double fishStorageShare;
  double meatStorageShare;
  double materialStorageShare;
  double goodsStorageShare;
  double busTicketFare;
  double transitRevenue = 0;
  int ticketsSold = 0;
  double fishProduction = 0;
  double meatProduction = 0;
  double _timer = 0;
  int _warehouseCount = 0;

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
        'foodStorageShare': foodStorageShare,
        'fishStorageShare': fishStorageShare,
        'meatStorageShare': meatStorageShare,
        'materialStorageShare': materialStorageShare,
        'goodsStorageShare': goodsStorageShare,
        'warehouseCount': _warehouseCount,
        'busTicketFare': busTicketFare,
        'transitRevenue': transitRevenue,
        'ticketsSold': ticketsSold,
        'fishProduction': fishProduction,
        'meatProduction': meatProduction,
        'timer': _timer,
      };

  factory MarketState.fromJson(Map<String, dynamic> data) {
    final market = MarketState(
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
      foodStorageCapacity: _read(data, 'foodStorageCapacity', 120),
      fishStorageCapacity: _read(data, 'fishStorageCapacity', 25),
      meatStorageCapacity: _read(data, 'meatStorageCapacity', 25),
      materialStorageCapacity: _read(data, 'materialStorageCapacity', 45),
      goodsStorageCapacity: _read(data, 'goodsStorageCapacity', 35),
      foodStorageShare: _read(data, 'foodStorageShare', .48),
      fishStorageShare: _read(data, 'fishStorageShare', .1),
      meatStorageShare: _read(data, 'meatStorageShare', .1),
      materialStorageShare: _read(data, 'materialStorageShare', .18),
      goodsStorageShare: _read(data, 'goodsStorageShare', .14),
      busTicketFare: _read(data, 'busTicketFare', .75).clamp(0, 3).toDouble(),
    ).._warehouseCount =
        _read(data, 'warehouseCount', 0).floor().clamp(0, 1 << 31);
    market._normalizeStorageShares();
    return market
      ..fishProduction = _read(data, 'fishProduction', 0)
      ..meatProduction = _read(data, 'meatProduction', 0)
      ..transitRevenue = _read(data, 'transitRevenue', 0)
      ..ticketsSold = _read(data, 'ticketsSold', 0).floor().clamp(0, 1 << 31)
      .._timer = _read(data, 'timer', 0).clamp(0, 10).toDouble();
  }

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
    _warehouseCount = max(0, warehouses).toInt();
    storageCapacity = 250 + _warehouseCount * 500;
    _recalculateStorageCaps();
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

  double storageShare(StoredResource resource) => switch (resource) {
        StoredResource.food => foodStorageShare,
        StoredResource.fish => fishStorageShare,
        StoredResource.meat => meatStorageShare,
        StoredResource.materials => materialStorageShare,
        StoredResource.goods => goodsStorageShare,
      };

  void setStorageShare(StoredResource resource, double requestedShare) {
    if (!requestedShare.isFinite) return;
    final next = requestedShare.clamp(.01, .8).toDouble();
    final previousOtherTotal = 1 - storageShare(resource);
    final nextOtherTotal = 1 - next;
    double redistribute(double share) => previousOtherTotal <= 0
        ? nextOtherTotal / 4
        : share * nextOtherTotal / previousOtherTotal;
    switch (resource) {
      case StoredResource.food:
        foodStorageShare = next;
        fishStorageShare = redistribute(fishStorageShare);
        meatStorageShare = redistribute(meatStorageShare);
        materialStorageShare = redistribute(materialStorageShare);
        goodsStorageShare = redistribute(goodsStorageShare);
        break;
      case StoredResource.fish:
        fishStorageShare = next;
        foodStorageShare = redistribute(foodStorageShare);
        meatStorageShare = redistribute(meatStorageShare);
        materialStorageShare = redistribute(materialStorageShare);
        goodsStorageShare = redistribute(goodsStorageShare);
        break;
      case StoredResource.meat:
        meatStorageShare = next;
        foodStorageShare = redistribute(foodStorageShare);
        fishStorageShare = redistribute(fishStorageShare);
        materialStorageShare = redistribute(materialStorageShare);
        goodsStorageShare = redistribute(goodsStorageShare);
        break;
      case StoredResource.materials:
        materialStorageShare = next;
        foodStorageShare = redistribute(foodStorageShare);
        fishStorageShare = redistribute(fishStorageShare);
        meatStorageShare = redistribute(meatStorageShare);
        goodsStorageShare = redistribute(goodsStorageShare);
        break;
      case StoredResource.goods:
        goodsStorageShare = next;
        foodStorageShare = redistribute(foodStorageShare);
        fishStorageShare = redistribute(fishStorageShare);
        meatStorageShare = redistribute(meatStorageShare);
        materialStorageShare = redistribute(materialStorageShare);
        break;
    }
    _recalculateStorageCaps();
    _fitInventoryToCapacity();
  }

  void _normalizeStorageShares() {
    final total = foodStorageShare +
        fishStorageShare +
        meatStorageShare +
        materialStorageShare +
        goodsStorageShare;
    if (!total.isFinite || total <= 0) {
      foodStorageShare = .48;
      fishStorageShare = .1;
      meatStorageShare = .1;
      materialStorageShare = .18;
      goodsStorageShare = .14;
      return;
    }
    foodStorageShare /= total;
    fishStorageShare /= total;
    meatStorageShare /= total;
    materialStorageShare /= total;
    goodsStorageShare /= total;
  }

  void _recalculateStorageCaps() {
    foodStorageCapacity = storageCapacity * foodStorageShare;
    fishStorageCapacity = storageCapacity * fishStorageShare;
    meatStorageCapacity = storageCapacity * meatStorageShare;
    materialStorageCapacity = storageCapacity * materialStorageShare;
    goodsStorageCapacity = storageCapacity * goodsStorageShare;
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
