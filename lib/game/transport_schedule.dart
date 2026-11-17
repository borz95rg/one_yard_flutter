/// One circular bus follows the route during the daytime service window.
/// Route progress is normalized to [0, 1], with a full circuit every two
/// in-game hours.
class BusSchedule {
  const BusSchedule._();

  static const double serviceStartsAt = 6;
  static const double serviceEndsAt = 22;
  static const double circuitHours = 2;

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
}
