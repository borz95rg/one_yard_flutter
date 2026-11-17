import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/transport_schedule.dart';

void main() {
  test('bus service runs from 06:00 through 22:00', () {
    expect(BusSchedule.isOperatingAt(5.99), isFalse);
    expect(BusSchedule.isOperatingAt(6), isTrue);
    expect(BusSchedule.isOperatingAt(21.99), isTrue);
    expect(BusSchedule.isOperatingAt(22), isFalse);
  });

  test('route repeats every two in-game hours while the service is active', () {
    expect(BusSchedule.routeProgressAt(6), 0);
    expect(BusSchedule.routeProgressAt(7), 0.5);
    expect(BusSchedule.routeProgressAt(8), 0);
    expect(BusSchedule.routeProgressAt(21.5), 0.75);
    expect(BusSchedule.routeProgressAt(23), 0);
  });

  test('depot fleet is evenly spaced and parked outside service hours', () {
    expect(BusSchedule.fleetSize(hasDepot: false), 1);
    expect(BusSchedule.fleetSize(hasDepot: true), 3);
    expect(
      BusSchedule.fleetProgressesAt(6, fleetSize: 3),
      [0, 1 / 3, 2 / 3],
    );
    expect(BusSchedule.fleetProgressesAt(22, fleetSize: 3), isEmpty);
  });
}
