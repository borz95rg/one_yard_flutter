import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/city_economy.dart';

void main() {
  test('warehouses enforce separate limits for each resource', () {
    final market = MarketState(
      food: 900,
      fishStock: 900,
      meatStock: 900,
      materials: 900,
      goods: 900,
    );

    market.update(
      dt: 0,
      residents: const [],
      sites: const [],
      warehouses: 1,
    );

    expect(market.food, market.foodStorageCapacity);
    expect(market.fishStock, market.fishStorageCapacity);
    expect(market.meatStock, market.meatStorageCapacity);
    expect(market.materials, market.materialStorageCapacity);
    expect(market.goods, market.goodsStorageCapacity);
    expect(market.storageCapacity, 750);
    expect(market.storedResources, market.storageCapacity);
  });

  test('resource-specific storage capacities survive a save round-trip', () {
    final market = MarketState()..goodsStorageCapacity = 321;

    final restored = MarketState.fromJson(market.toJson());

    expect(restored.goodsStorageCapacity, 321);
  });

  test('storage share changes keep the total capacity and persist', () {
    final market = MarketState();
    market.update(
      dt: 0,
      residents: const [],
      sites: const [],
      warehouses: 1,
    );

    market.setStorageShare(StoredResource.fish, .3);

    expect(market.fishStorageCapacity, 225);
    expect(market.storageCapacity, 750);
    expect(
      market.foodStorageShare +
          market.fishStorageShare +
          market.meatStorageShare +
          market.materialStorageShare +
          market.goodsStorageShare,
      closeTo(1, 1e-9),
    );
    final restored = MarketState.fromJson(market.toJson());
    expect(restored.fishStorageShare, closeTo(.3, 1e-9));
  });
}
