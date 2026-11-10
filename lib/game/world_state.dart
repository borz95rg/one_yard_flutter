/// Typed migration slice for the original HTML game's world clock, seasons,
/// weather, ecology and historical era.
///
/// This intentionally does not simulate season transitions or natural events;
/// those rules remain in the HTML reference until they are ported and tested.
class WorldState {
  const WorldState({
    required this.seasonIndex,
    required this.seasonTimer,
    required this.worldYear,
    required this.weather,
    required this.weatherTimer,
    required this.currentEraIndex,
    required this.nature,
    this.natureEventTimer = 0,
  });

  static const int seasonCount = 4;
  static const Map<String, double> defaultNature = {
    'forest': 72,
    'wildlife': 65,
    'soil': 78,
    'pollution': 8,
    'harvests': 0,
    'droughts': 0,
    'floods': 0,
    'storms': 0,
    'wildfires': 0,
    'foodLoss': 0,
  };

  final int seasonIndex;
  final double seasonTimer;
  final int worldYear;
  final String weather;
  final double weatherTimer;
  final int currentEraIndex;
  final Map<String, double> nature;
  final double natureEventTimer;

  factory WorldState.initial() => WorldState(
        seasonIndex: 0,
        seasonTimer: 0,
        worldYear: 1,
        weather: 'Ясно',
        weatherTimer: 0,
        currentEraIndex: 0,
        nature: Map.unmodifiable(defaultNature),
        natureEventTimer: 0,
      );

  /// Maps only fields verified in saveYard()/loadYard() of HTML v19.
  factory WorldState.fromLegacyHtml(Map<String, dynamic> legacy) {
    final rawNature = legacy['nature'];
    final nature = <String, double>{...defaultNature};
    if (rawNature is Map) {
      for (final entry in rawNature.entries) {
        final value = _finiteNumber(entry.value);
        if (value != null) nature['${entry.key}'] = value;
      }
    }

    return WorldState(
      seasonIndex: _integer(legacy['seasonIndex'], fallback: 0).clamp(0, 3).toInt(),
      seasonTimer: _nonNegative(legacy['seasonTimer']),
      worldYear: _integer(legacy['worldYear'], fallback: 1).clamp(1, 1 << 31).toInt(),
      weather: legacy['weather'] is String ? legacy['weather'] as String : 'Ясно',
      weatherTimer: _nonNegative(legacy['weatherTimer']),
      currentEraIndex: _integer(legacy['currentEraIndex'], fallback: 0).clamp(0, 5).toInt(),
      nature: Map.unmodifiable(nature),
      natureEventTimer: _nonNegative(legacy['natureEventTimer']),
    );
  }

  factory WorldState.fromJson(Map<String, dynamic> json) =>
      WorldState.fromLegacyHtml(json);

  Map<String, dynamic> toJson() => {
        'seasonIndex': seasonIndex,
        'seasonTimer': seasonTimer,
        'worldYear': worldYear,
        'weather': weather,
        'weatherTimer': weatherTimer,
        'currentEraIndex': currentEraIndex,
        'nature': nature,
        'natureEventTimer': natureEventTimer,
      };

  static int _integer(Object? value, {required int fallback}) =>
      value is num && value.isFinite ? value.toInt() : fallback;

  static double _nonNegative(Object? value) {
    final number = _finiteNumber(value) ?? 0;
    return number < 0 ? 0 : number;
  }

  static double? _finiteNumber(Object? value) {
    if (value is! num || !value.isFinite) return null;
    return value.toDouble();
  }
}
