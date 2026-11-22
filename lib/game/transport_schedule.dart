/// A scheduled fleet shares one circular route during the daytime service
/// window. Buses are evenly spaced, and each vehicle completes a circuit in
/// two in-game hours.
class BusSchedule {
  const BusSchedule._();

  static const double serviceStartsAt = 6;
  static const double serviceEndsAt = 22;
  static const double circuitHours = 2;
  static const int basicFleetSize = 1;
  static const int depotFleetSize = 3;

  static int fleetSize({required bool hasDepot}) =>
      hasDepot ? depotFleetSize : basicFleetSize;

  static bool isOperatingAt(double hourOfDay) {
    if (!hourOfDay.isFinite) return false;
    final hour = hourOfDay % 24;
    return hour >= serviceStartsAt && hour < serviceEndsAt;
  }

  static double routeProgressAt(double hourOfDay) {
    if (!isOperatingAt(hourOfDay)) return 0;
    final hour = hourOfDay % 24;
    return ((hour - serviceStartsAt) % circuitHours) / circuitHours;
  }

  static List<double> fleetProgressesAt(
    double hourOfDay, {
    required int fleetSize,
  }) {
    if (!isOperatingAt(hourOfDay) || fleetSize <= 0) return const [];
    final first = routeProgressAt(hourOfDay);
    return List<double>.generate(
      fleetSize,
      (vehicle) => (first + vehicle / fleetSize) % 1,
      growable: false,
    );
  }
}
