import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game/city_economy.dart';
import 'game/civilization_simulation.dart';
import 'game/isometric_grid.dart';
import 'game/nature_simulation.dart';
import 'game/resident_simulation.dart';
import 'game/world_state.dart';
import 'persistence/game_save.dart';
import 'persistence/io_save_file_store.dart';
import 'persistence/save_storage.dart';

void main() => runApp(const OneYardApp());

class OneYardApp extends StatelessWidget {
  const OneYardApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Один двор — целая цивилизация',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xff10201e),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffe5ad39),
            brightness: Brightness.dark,
          ),
        ),
        home: const SettlementScreen(),
      );
}

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});
  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen>
    with WidgetsBindingObserver {
  late final SettlementGame game;
  double _previousScale = 1;
  int _selectedTool = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = SettlementGame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(game.save());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(game.save());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            return Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (_) => _previousScale = 1,
                  onScaleUpdate: (details) {
                    final factor = details.scale / _previousScale;
                    _previousScale = details.scale;
                    game.pan(
                        details.focalPointDelta.dx, details.focalPointDelta.dy);
                    if (details.pointerCount > 1) game.zoom(factor);
                  },
                  onTapUp: (details) {
                    if (game.placeAtScreen(
                        details.localPosition, _selectedTool)) {
                      setState(() {});
                    } else if (details.localPosition.dy > 130 &&
                        details.localPosition.dy <
                            constraints.maxHeight - 110) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Здесь нельзя строить или не хватает стройматериалов'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: GameWidget(game: game),
                ),
              ),
              Positioned(
                  left: 10,
                  right: 10,
                  top: 8,
                  child: _TopBar(compact: compact, game: game)),
              if (!compact) ...[
                Positioned(
                    left: 10,
                    top: 125,
                    bottom: 125,
                    width: 226,
                    child: _LeftDashboard(game: game)),
                Positioned(
                    right: 10,
                    top: 125,
                    width: 218,
                    child: _DistrictPanel(game: game)),
                Positioned(
                    left: 10,
                    bottom: 116,
                    width: 390,
                    child: _EventsPanel(events: game.events)),
                Positioned(
                    right: 10,
                    bottom: 116,
                    child: _TechnologyPanel(civilization: game.civilization)),
              ] else ...[
                Positioned(
                    left: 10,
                    right: 10,
                    top: 76,
                    child: _CompactStats(game: game)),
              ],
              Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: _BuildBar(
                    compact: compact,
                    selected: _selectedTool,
                    onSelect: (value) => setState(() => _selectedTool = value),
                  )),
            ]);
          }),
        ),
      );
}

class SettlementGame extends FlameGame {
  late final SettlementMap map;
  final ValueNotifier<ResidentMetrics> residents = ValueNotifier(
    const ResidentMetrics(
        population: 8,
        children: 0,
        adults: 8,
        elders: 0,
        couples: 0,
        familyLines: 8,
        generations: 1),
  );
  final ValueNotifier<EconomyMetrics> economy = ValueNotifier(
    const EconomyMetrics(
        food: 45,
        materials: 28,
        goods: 18,
        treasury: 0,
        taxRate: .08,
        tradeVolume: 0),
  );
  final ValueNotifier<WorldState> worldState =
      ValueNotifier(WorldState.initial());
  final ValueNotifier<CivilizationSimulation> civilization =
      ValueNotifier(CivilizationSimulation());
  final ValueNotifier<List<int>> districtShares =
      ValueNotifier(const [40, 20, 20, 20]);
  final ValueNotifier<List<String>> events = ValueNotifier(const []);
  final ValueNotifier<bool> pauseState = ValueNotifier(false);
  final ValueNotifier<int> speedIndex = ValueNotifier(0);
  static const speeds = [1.0, 2.0, 4.0];
  double _refreshTimer = 0;
  double _saveTimer = 0;
  GameSaveRepository? _saveRepository;
  Map<String, dynamic>? _legacyHtmlSave;
  bool _saving = false;

  @override
  Color backgroundColor() => const Color(0xff183b3b);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.zoom = .82;
    try {
      _saveRepository = GameSaveRepository(await IoSaveFileStore.create());
    } catch (_) {
      // The scene remains playable on platforms without app-private storage.
    }
    map = SettlementMap(artwork: await images.load('city_map_crop.jpg'));
    final previous = await _saveRepository?.load();
    if (previous != null) {
      map.restore(previous);
      _legacyHtmlSave = previous.legacyHtmlSave;
    }
    world.add(map);
  }

  @override
  void update(double dt) {
    if (pauseState.value) return;
    super.update(dt * speeds[speedIndex.value]);
    if (!isLoaded) return;
    _saveTimer += dt * speeds[speedIndex.value];
    if (_saveTimer >= 30) {
      _saveTimer = 0;
      unawaited(save());
    }
    _refreshTimer += dt;
    if (_refreshTimer >= .5) {
      _refreshTimer = 0;
      residents.value = map.people.metrics;
      economy.value = map.market.metrics;
      worldState.value = map.climate;
      civilization.value = map.civilization;
      districtShares.value = map.districtShares;
      events.value = map.recentEvents.take(4).toList(growable: false);
    }
  }

  void pan(double dx, double dy) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position.add(Vector2(-dx / zoom, -dy / zoom));
  }

  void zoom(double factor) {
    if (factor.isFinite && factor > 0) {
      camera.viewfinder.zoom =
          (camera.viewfinder.zoom * factor).clamp(.45, 2.2);
    }
  }

  void togglePause() => pauseState.value = !pauseState.value;

  void cycleSpeed() =>
      speedIndex.value = (speedIndex.value + 1) % speeds.length;

  void refreshFromMap() {
    if (!isLoaded) return;
    residents.value = map.people.metrics;
    economy.value = map.market.metrics;
    worldState.value = map.climate;
    civilization.value = map.civilization;
    districtShares.value = map.districtShares;
    events.value = map.recentEvents.take(4).toList(growable: false);
  }

  Future<void> save() async {
    final repository = _saveRepository;
    if (repository == null || !isLoaded || _saving) return;
    _saving = true;
    try {
      await repository.save(GameSave(
        schemaVersion: GameSave.currentSchemaVersion,
        savedAtUtc: DateTime.now().toUtc(),
        payload: map.toJson(),
        legacyHtmlSave: _legacyHtmlSave,
      ));
    } catch (error) {
      events.value = ['Не удалось сохранить игру: $error', ...events.value]
          .take(4)
          .toList();
    } finally {
      _saving = false;
    }
  }

  bool placeAtScreen(Offset point, int kind) {
    if (!isLoaded) return false;
    final zoom = camera.viewfinder.zoom;
    final worldX =
        camera.viewfinder.position.x + (point.dx - size.x / 2) / zoom;
    final worldY =
        camera.viewfinder.position.y + (point.dy - size.y / 2) / zoom;
    final origin =
        map.cellCenter(SettlementMap.columns ~/ 2, SettlementMap.rows ~/ 2);
    final cell = IsometricGrid(
      columns: SettlementMap.columns,
      rows: SettlementMap.rows,
      tileWidth: SettlementMap.tileW,
      tileHeight: SettlementMap.tileH,
    ).cellAt(IsometricPoint(worldX + origin.x, worldY + origin.y));
    return cell != null && map.placeBuilding(cell, kind);
  }

  @override
  void onRemove() {
    residents.dispose();
    economy.dispose();
    worldState.dispose();
    civilization.dispose();
    districtShares.dispose();
    events.dispose();
    pauseState.dispose();
    speedIndex.dispose();
    super.onRemove();
  }
}

class _Building {
  const _Building(this.column, this.row, this.kind, {this.visible = false});
  final int column, row, kind;
  final bool visible;
}

class SettlementMap extends Component {
  SettlementMap({this.artwork});

  final ui.Image? artwork;
  static const columns = 28, rows = 24;
  static const tileW = 68.0, tileH = 36.0;
  final List<_Building> _buildings = [
    const _Building(13, 10, 3),
    const _Building(10, 12, 0),
    const _Building(16, 12, 1),
    const _Building(12, 15, 2),
    const _Building(18, 15, 0),
    const _Building(8, 9, 1),
    const _Building(20, 10, 2),
    const _Building(15, 7, 0),
    const _Building(6, 14, 0),
    const _Building(21, 17, 1),
  ];
  late ResidentSimulation people = ResidentSimulation.initial(
    sites: _defaultSites(),
    width: tileW * columns,
    height: tileH * rows,
  );
  MarketState market = MarketState();
  final NatureSimulation nature = NatureSimulation();
  CivilizationSimulation civilization = CivilizationSimulation();
  WorldState climate = WorldState.initial();
  double _timeOfDay = .35;
  double _housingGrowthTimer = 0;
  final List<String> recentEvents = [];
  Map<String, dynamic>? legacyHtmlSave;

  List<ResidentSite> _defaultSites() => [
        for (final b in _buildings)
          ResidentSite(cellCenter(b.column, b.row), _roleForKind(b.kind)),
        ResidentSite(cellCenter(23, 12), 'источник воды'),
        ResidentSite(cellCenter(5, 18), 'парк отдыха'),
      ];

  List<int> get districtShares {
    const kinds = [0, 2, 1, 4];
    final recognized = _buildings.where((b) => kinds.contains(b.kind)).length;
    if (recognized == 0) return const [0, 0, 0, 0];
    return [
      for (final kind in kinds)
        (_buildings.where((b) => b.kind == kind).length * 100 / recognized)
            .round(),
    ];
  }

  Map<String, dynamic> toJson() => {
        'buildings': [
          for (final building in _buildings)
            {
              'column': building.column,
              'row': building.row,
              'kind': building.kind,
              'visible': building.visible,
            },
        ],
        'residents': people.toJson(),
        'market': market.toJson(),
        'civilization': civilization.toJson(),
        'worldState': climate.toJson(),
        'timeOfDay': _timeOfDay,
      };

  void restore(GameSave save) {
    final legacy = save.legacyHtmlSave;
    legacyHtmlSave = legacy;
    final payload = save.payload;
    final savedBuildings = payload['buildings'];
    if (savedBuildings is List) {
      final restored = <_Building>[];
      for (final item in savedBuildings.whereType<Map>()) {
        final col = item['column'], row = item['row'], kind = item['kind'];
        if (col is int &&
            row is int &&
            kind is int &&
            col >= 0 &&
            col < columns &&
            row >= 0 &&
            row < rows &&
            kind >= 0 &&
            kind < 12) {
          restored.add(_Building(col, row, kind,
              visible:
                  item['visible'] is bool ? item['visible'] as bool : true));
        }
      }
      if (restored.isNotEmpty) {
        _buildings
          ..clear()
          ..addAll(restored);
      }
    }
    final worldData = payload['worldState'];
    if (worldData is Map) {
      climate = WorldState.fromJson(Map<String, dynamic>.from(worldData));
    } else if (legacy != null) {
      climate = WorldState.fromLegacyHtml(legacy);
    }
    final marketData = payload['market'] is Map
        ? Map<String, dynamic>.from(payload['market'] as Map)
        : legacy?['market'] is Map
            ? Map<String, dynamic>.from(legacy!['market'] as Map)
            : null;
    if (marketData != null) {
      if (legacy != null) {
        marketData['treasury'] ??= legacy['cityTreasury'];
        marketData['taxRate'] ??= legacy['cityTaxRate'];
      }
      market = MarketState.fromJson(marketData);
    }
    final civilizationData = payload['civilization'];
    if (civilizationData is Map) {
      civilization = CivilizationSimulation.fromJson(
          Map<String, dynamic>.from(civilizationData));
    } else if (legacy != null) {
      civilization = CivilizationSimulation.fromLegacy(legacy);
    }
    final residentsData = payload['residents'];
    if (residentsData is List) {
      people = ResidentSimulation.restore(
        source: residentsData,
        sites: _defaultSites(),
        width: tileW * columns,
        height: tileH * rows,
      );
    } else if (legacy != null && legacy['residents'] is List) {
      people = ResidentSimulation.fromLegacySave(
        source: legacy['residents'],
        sites: [..._defaultSites(), ..._legacySites(legacy['objects'])],
        width: tileW * columns,
        height: tileH * rows,
      );
      legacyHtmlSave = legacy;
    }
    final time = payload['timeOfDay'];
    if (time is num && time.isFinite) {
      _timeOfDay = time.toDouble().clamp(0, 1).toDouble();
    }
    if (legacy != null) {
      recentEvents.insert(0,
          'Сохранение HTML ${legacy['version'] ?? '?'} импортировано; исходные данные сохранены');
    }
  }

  List<ResidentSite> _legacySites(Object? source) {
    if (source is! List) return const [];
    final objects = source.whereType<Map>().toList();
    if (objects.isEmpty) return const [];
    final xs = objects
        .map((o) => o['x'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    final ys = objects
        .map((o) => o['y'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    if (xs.isEmpty || ys.isEmpty) return const [];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    return [
      for (final object in objects)
        if (object['x'] is num && object['y'] is num)
          ResidentSite(
            IsometricPoint(
              _normalizeCoordinate(
                      (object['x'] as num).toDouble(), minX, maxX) *
                  tileW *
                  columns,
              _normalizeCoordinate(
                      (object['y'] as num).toDouble(), minY, maxY) *
                  tileH *
                  rows,
            ),
            _legacyRole(object),
          ),
    ];
  }

  static double _normalizeCoordinate(
          double value, double minimum, double maximum) =>
      maximum == minimum
          ? 0
          : ((value - minimum) / (maximum - minimum) - .5) * .75;

  static String _legacyRole(Map object) {
    final role = object['role'];
    if (role is String && role.isNotEmpty) return role;
    return switch ('${object['type']}') {
      'boot' => 'дом',
      'puddle' => 'источник воды',
      'stick' => 'дерево',
      'stone' => 'алтарь',
      _ => 'парк отдыха',
    };
  }

  IsometricPoint cellCenter(int column, int row) => IsometricPoint(
        (column - row) * tileW / 2,
        (column + row) * tileH / 2,
      );

  bool placeBuilding(GridCell cell, int kind) {
    if (kind < 0 ||
        kind > 11 ||
        _buildings.any((b) => b.column == cell.column && b.row == cell.row)) {
      return false;
    }
    if (kind == 8 && cell.column < 20) return false;
    if (kind == 11 && !_hasAdjacentRoad(cell.column, cell.row)) return false;
    final costs = [8.0, 12, 15, 20, 7, 22, 30, 4, 18, 20, 16, 8];
    final cost = costs[kind];
    if (market.materials < cost) {
      return false;
    }
    market.materials -= cost;
    _buildings.add(_Building(cell.column, cell.row, kind, visible: true));
    people.sites.add(
        ResidentSite(cellCenter(cell.column, cell.row), _roleForKind(kind)));
    recentEvents.insert(
        0, 'Построено: ${_buildingName(kind)} (−${cost.toInt()} строймат.)');
    return true;
  }

  bool _hasAdjacentRoad(int column, int row) => _buildings.any((building) =>
      building.kind == 7 &&
      (building.column - column).abs() + (building.row - row).abs() == 1);

  static String _buildingName(int kind) => const [
        'жилой дом',
        'ферма',
        'рынок',
        'инфраструктура',
        'парк',
        'служба',
        'уникальное здание',
        'дорога',
        'рыбная пристань',
        'животноводческая ферма',
        'склад',
        'автобусная остановка',
      ][kind];

  static String _roleForKind(int kind) => switch (kind) {
        0 => 'дом',
        1 => 'ферма',
        2 => 'рынок',
        4 => 'парк',
        5 => 'больница',
        6 => 'памятник',
        7 => 'дорога',
        8 => 'рыболовство',
        9 => 'животноводство',
        10 => 'склад',
        11 => 'автобусная остановка',
        _ => 'совет',
      };

  @override
  void update(double dt) {
    _timeOfDay = (_timeOfDay + dt / 180) % 1;
    _housingGrowthTimer += dt;
    final hour = (_timeOfDay * 24).floor();
    people.update(dt, isNight: hour < 6 || hour >= 20, hour: hour);
    market.update(
      dt: dt,
      residents: people.residents,
      sites: people.sites,
      technologyLevel: civilization.technologyLevel,
      eraIndex: civilization.eraIndex,
      warehouses: _buildings.where((building) => building.kind == 10).length,
    );
    final cityEvents = civilization.update(
      dt: dt,
      residents: people.residents,
      sites: people.sites,
      market: market,
    );
    if (cityEvents.isNotEmpty) {
      recentEvents.insertAll(0, cityEvents);
      if (recentEvents.length > 8) {
        recentEvents.removeRange(8, recentEvents.length);
      }
    }
    if (_housingGrowthTimer >= 10) {
      _housingGrowthTimer %= 10;
      _growHousing();
    }
    final result = nature.update(
      state: climate,
      dt: dt,
      residentCount: people.residents.length,
      food: market.food,
      farmCount: _buildings.where((building) => building.kind == 1).length,
      technologyLevel: civilization.technologyLevel,
    );
    climate = result.state;
    market.food = math.min(result.food, market.storageCapacity);
    if (result.residentMoraleDelta != 0) {
      for (final resident in people.residents) {
        resident.morale = (resident.morale + result.residentMoraleDelta)
            .clamp(0, 1)
            .toDouble();
      }
    }
    if (result.events.isNotEmpty) {
      recentEvents.insertAll(0, result.events);
      if (recentEvents.length > 8) {
        recentEvents.removeRange(8, recentEvents.length);
      }
    }
  }

  void _growHousing() {
    final homes = _buildings.where((building) => building.kind == 0).length;
    if (people.residents.length <= homes * 4 ||
        market.treasury < 25 ||
        market.materials < 10) {
      return;
    }
    for (var row = 4; row < rows - 3; row++) {
      for (var column = 3; column < columns - 3; column++) {
        if (_buildings.any((b) => b.column == column && b.row == row)) continue;
        market.treasury -= 25;
        market.materials -= 10;
        _buildings.add(_Building(column, row, 0, visible: true));
        people.sites.add(ResidentSite(cellCenter(column, row), 'дом'));
        recentEvents.insert(0, '🏘️ Город автоматически расширил жилой район');
        return;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final origin = cellCenter(columns ~/ 2, rows ~/ 2);
    canvas.save();
    canvas.translate(-origin.x, -origin.y);
    if (artwork != null) {
      canvas.drawImageRect(
        artwork!,
        Rect.fromLTWH(
            0, 0, artwork!.width.toDouble(), artwork!.height.toDouble()),
        const Rect.fromLTWH(-884, -468, 1768, 936),
        Paint()..filterQuality = FilterQuality.high,
      );
      _drawFactionTerritories(canvas);
    } else {
      _drawTerrain(canvas);
      _drawFactionTerritories(canvas);
      _drawRoads(canvas);
      _drawRiver(canvas);
      _drawTrees(canvas);
    }
    final sorted = [..._buildings]
      ..sort((a, b) => (a.column + a.row).compareTo(b.column + b.row));
    final roadKeys = _buildings
        .where((building) => building.kind == 7)
        .map((building) => building.row * columns + building.column)
        .toSet();
    for (final building in sorted) {
      if (building.visible) _drawBuilding(canvas, building, roadKeys);
    }
    _drawTraffic(canvas);
    _drawPeople(canvas);
    canvas.restore();
  }

  static const _trafficRoutes = <List<Offset>>[
    [
      Offset(0, 352),
      Offset(170, 350),
      Offset(360, 362),
      Offset(560, 395),
      Offset(790, 455),
      Offset(1010, 505),
      Offset(1195, 566),
    ],
    [
      Offset(0, 276),
      Offset(165, 256),
      Offset(330, 274),
      Offset(480, 326),
      Offset(620, 360),
      Offset(815, 364),
      Offset(1015, 335),
      Offset(1195, 300),
    ],
    [
      Offset(430, 300),
      Offset(565, 286),
      Offset(700, 250),
      Offset(825, 194),
      Offset(940, 132),
      Offset(1048, 96),
    ],
    [
      Offset(310, 170),
      Offset(420, 235),
      Offset(520, 315),
      Offset(630, 388),
      Offset(760, 455),
      Offset(900, 504),
    ],
    [
      Offset(1195, 414),
      Offset(1040, 405),
      Offset(900, 394),
      Offset(760, 376),
      Offset(625, 350),
      Offset(490, 320),
      Offset(350, 302),
    ],
  ];

  void _drawTraffic(Canvas canvas) {
    if (artwork == null || people.residents.length < 3) return;
    final stage = (people.residents.length / 70).clamp(0, 1).toDouble();
    final count = math.min(22, 2 + (stage * 20).floor());
    final roadRoute = _connectedRoadRoute();
    final playerRoadPoints = roadRoute
        .map((building) => cellCenter(building.column, building.row))
        .map((point) => Offset(point.x, point.y))
        .toList(growable: false);
    final busRoutePoints = _busRoutePoints();
    final colors = [
      const Color(0xffbd594a),
      const Color(0xff6d9db7),
      const Color(0xffd2c6a6),
      const Color(0xff79966e),
      const Color(0xff514c48),
    ];
    const artWidth = 1195.0, artHeight = 600.0;
    for (var i = 0; i < count; i++) {
      final bus = (busRoutePoints.length > 1 && i % 5 == 0) ||
          (stage > .68 && i % 7 == 0);
      final usesBusStops = bus && busRoutePoints.length > 1;
      final usesPlayerRoads = !usesBusStops && playerRoadPoints.length > 1;
      final route = usesBusStops
          ? busRoutePoints
          : usesPlayerRoads
              ? playerRoadPoints
              : _trafficRoutes[i % _trafficRoutes.length];
      final direction = i.isEven ? 1.0 : -1.0;
      final cycle = (_timeOfDay * 24 * 2.4 * direction + i * 1.73) % 18;
      final progress = ((cycle + 18) % 18) / 18;
      final sample = _sampleRoute(route, progress);
      final x = usesPlayerRoads
          ? sample.$1.dx
          : (sample.$1.dx / artWidth - .5) * 1768;
      final y = usesPlayerRoads
          ? sample.$1.dy
          : (sample.$1.dy / artHeight - .5) * 936;
      final tangentX =
          usesPlayerRoads ? sample.$2.dx : sample.$2.dx * 1768 / artWidth;
      final tangentY =
          usesPlayerRoads ? sample.$2.dy : sample.$2.dy * 936 / artHeight;
      final angle = math.atan2(tangentY, tangentX);
      final length = bus ? 28.0 : 17.0;
      final height = bus ? 9.0 : 7.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(1, 4), width: length + 3, height: 7),
        Paint()..color = const Color(0x880b1314),
      );
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length, height: height),
        const Radius.circular(2),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xff171b1b));
      canvas.drawRRect(
        body,
        Paint()
          ..color = bus ? const Color(0xffd3a84c) : colors[i % colors.length]
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(bus ? -1 : 0, -1),
            width: bus ? 16 : 8,
            height: 3,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xffb7d3d8),
      );
      final lamp = Paint()..color = const Color(0xffffe6a3);
      canvas.drawCircle(Offset(length / 2 - 1, -1.5), .8, lamp);
      canvas.drawCircle(Offset(length / 2 - 1, 1.5), .8, lamp);
      canvas.restore();
    }
  }

  List<_Building> _connectedRoadRoute() {
    final roads = _buildings.where((building) => building.kind == 7).toList();
    if (roads.length < 2) return const [];
    roads.sort((a, b) =>
        (a.row * columns + a.column).compareTo(b.row * columns + b.column));
    int key(_Building building) => building.row * columns + building.column;
    final roadByKey = {for (final road in roads) key(road): road};
    Iterable<int> adjacentKeys(int currentKey) sync* {
      final row = currentKey ~/ columns;
      final column = currentKey % columns;
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nextColumn = column + dc, nextRow = row + dr;
        if (nextColumn < 0 ||
            nextColumn >= columns ||
            nextRow < 0 ||
            nextRow >= rows) {
          continue;
        }
        final nextKey = nextRow * columns + nextColumn;
        if (roadByKey.containsKey(nextKey)) yield nextKey;
      }
    }

    final unseen = roadByKey.keys.toSet();
    var largestComponent = <int>[];
    while (unseen.isNotEmpty) {
      final first = unseen.first;
      final componentQueue = <int>[first];
      final component = <int>{first};
      unseen.remove(first);
      for (var cursor = 0; cursor < componentQueue.length; cursor++) {
        for (final nextKey in adjacentKeys(componentQueue[cursor])) {
          if (component.add(nextKey)) {
            unseen.remove(nextKey);
            componentQueue.add(nextKey);
          }
        }
      }
      if (component.length > largestComponent.length) {
        largestComponent = component.toList();
      }
    }
    if (largestComponent.length < 2) return const [];

    final startKey = largestComponent.first;
    final queue = <int>[startKey];
    final previous = <int, int?>{startKey: null};
    for (var cursor = 0; cursor < queue.length; cursor++) {
      for (final nextKey in adjacentKeys(queue[cursor])) {
        if (!previous.containsKey(nextKey)) {
          previous[nextKey] = queue[cursor];
          queue.add(nextKey);
        }
      }
    }
    final destination = queue.last;
    final route = <_Building>[];
    int? currentKey = destination;
    while (currentKey != null) {
      final current = roadByKey[currentKey];
      if (current == null) break;
      route.add(current);
      currentKey = previous[currentKey];
    }
    return route.reversed.toList(growable: false);
  }

  List<Offset> _busRoutePoints() {
    final stops = _buildings.where((building) => building.kind == 11).toList()
      ..sort((a, b) =>
          (a.row * columns + a.column).compareTo(b.row * columns + b.column));
    if (stops.length < 2) return const [];
    final roads = <int, _Building>{
      for (final road in _buildings.where((building) => building.kind == 7))
        road.row * columns + road.column: road,
    };
    int? attachedRoadKey(_Building stop) {
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final column = stop.column + dc, row = stop.row + dr;
        if (column < 0 || column >= columns || row < 0 || row >= rows) continue;
        final roadKey = row * columns + column;
        if (roads.containsKey(roadKey)) return roadKey;
      }
      return null;
    }

    List<int> roadPath(int start, int destination) {
      if (!roads.containsKey(start) || !roads.containsKey(destination)) {
        return const [];
      }
      final queue = <int>[start];
      final previous = <int, int?>{start: null};
      for (var cursor = 0; cursor < queue.length; cursor++) {
        final key = queue[cursor];
        if (key == destination) break;
        final row = key ~/ columns, column = key % columns;
        for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nextColumn = column + dc, nextRow = row + dr;
          if (nextColumn < 0 ||
              nextColumn >= columns ||
              nextRow < 0 ||
              nextRow >= rows) {
            continue;
          }
          final nextKey = nextRow * columns + nextColumn;
          if (roads.containsKey(nextKey) && !previous.containsKey(nextKey)) {
            previous[nextKey] = key;
            queue.add(nextKey);
          }
        }
      }
      if (!previous.containsKey(destination)) return const [];
      final path = <int>[];
      int? key = destination;
      while (key != null) {
        path.add(key);
        key = previous[key];
      }
      return path.reversed.toList(growable: false);
    }

    final roadKeys = stops.map(attachedRoadKey).toList();
    if (roadKeys.any((key) => key == null)) return const [];
    final points = <Offset>[];
    for (var i = 0; i < stops.length; i++) {
      final from = stops[i], to = stops[(i + 1) % stops.length];
      final path = roadPath(roadKeys[i]!, roadKeys[(i + 1) % stops.length]!);
      if (path.isEmpty) return const [];
      if (points.isEmpty) {
        final position = cellCenter(from.column, from.row);
        points.add(Offset(position.x, position.y));
      }
      for (final roadKey in path) {
        final road = roads[roadKey]!;
        final position = cellCenter(road.column, road.row);
        points.add(Offset(position.x, position.y));
      }
      final stopPosition = cellCenter(to.column, to.row);
      points.add(Offset(stopPosition.x, stopPosition.y));
    }
    return points.length > 1 ? points : const [];
  }

  static (Offset, Offset) _sampleRoute(List<Offset> points, double progress) {
    var totalLength = 0.0;
    final lengths = <double>[];
    for (var i = 1; i < points.length; i++) {
      final delta = points[i] - points[i - 1];
      final length = delta.distance;
      lengths.add(length);
      totalLength += length;
    }
    var remaining = totalLength * progress;
    for (var i = 0; i < lengths.length; i++) {
      final length = lengths[i];
      if (remaining <= length || i == lengths.length - 1) {
        final from = points[i], to = points[i + 1];
        final fraction =
            length == 0 ? 0.0 : (remaining / length).clamp(0, 1).toDouble();
        return (from + (to - from) * fraction, to - from);
      }
      remaining -= length;
    }
    return (points.last, points.last - points[points.length - 2]);
  }

  void _drawFactionTerritories(Canvas canvas) {
    for (final faction in civilization.factions) {
      final center = Offset(faction.x, faction.y);
      final radius = 36 + faction.territory.clamp(0, 160) * .8;
      canvas.drawCircle(
          center, radius, Paint()..color = Color(faction.color).withAlpha(20));
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Color(faction.color).withAlpha(130)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _drawTerrain(Canvas canvas) {
    final fill = Paint();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final c = cellCenter(col, row);
        final diamond = Path()
          ..moveTo(c.x, c.y - tileH / 2)
          ..lineTo(c.x + tileW / 2, c.y)
          ..lineTo(c.x, c.y + tileH / 2)
          ..lineTo(c.x - tileW / 2, c.y)
          ..close();
        fill.color = Color.lerp(const Color(0xff467b48),
            const Color(0xff8da75d), ((col * 19 + row * 13) % 9) / 100)!;
        canvas.drawPath(diamond, fill);
        canvas.drawPath(
            diamond,
            Paint()
              ..color = const Color(0x2276a75b)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
  }

  void _drawRoads(Canvas canvas) {
    final road = Paint()
      ..color = const Color(0xff80785d)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xffc5b688)
      ..strokeWidth = 2;
    for (final row in [8, 13, 18]) {
      final a = cellCenter(1, row), b = cellCenter(columns - 2, row);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), road);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), edge);
    }
    for (final col in [7, 13, 19]) {
      final a = cellCenter(col, 1), b = cellCenter(col, rows - 2);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), road);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), edge);
    }
    final center = cellCenter(13, 13);
    canvas.drawCircle(Offset(center.x, center.y), 21,
        Paint()..color = const Color(0xffb7a878));
    canvas.drawCircle(Offset(center.x, center.y), 14,
        Paint()..color = const Color(0xff4daec2));
    canvas.drawCircle(Offset(center.x, center.y), 5,
        Paint()..color = const Color(0xffd9f7e8));
  }

  void _drawRiver(Canvas canvas) {
    final river = Path();
    for (var i = 0; i < rows; i++) {
      final p = cellCenter(24 + (i % 3 == 0 ? 1 : 0), i);
      if (i == 0) {
        river.moveTo(p.x, p.y);
      } else {
        river.lineTo(p.x, p.y);
      }
    }
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0x994ec1d1)
          ..strokeWidth = 30
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xff64c7d0)
          ..strokeWidth = 19
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  void _drawTrees(Canvas canvas) {
    for (var row = 1; row < rows; row += 3) {
      for (var col = 1; col < columns; col += 3) {
        if ((col * 3 + row * 5) % 7 < 3 || col > 22) continue;
        final c = cellCenter(col, row);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(c.x + 3, c.y + 5), width: 23, height: 10),
            Paint()..color = const Color(0x550f241b));
        canvas.drawRect(Rect.fromLTWH(c.x - 2, c.y - 10, 4, 15),
            Paint()..color = const Color(0xff72563b));
        canvas.drawCircle(Offset(c.x, c.y - 14), 10,
            Paint()..color = const Color(0xff316c3b));
        canvas.drawCircle(Offset(c.x - 4, c.y - 17), 5,
            Paint()..color = const Color(0xff559148));
      }
    }
  }

  void _drawBuilding(Canvas canvas, _Building b, Set<int> roadKeys) {
    final c = cellCenter(b.column, b.row);
    if (b.kind == 7) {
      final road = Path()
        ..moveTo(c.x, c.y - tileH / 2)
        ..lineTo(c.x + tileW / 2, c.y)
        ..lineTo(c.x, c.y + tileH / 2)
        ..lineTo(c.x - tileW / 2, c.y)
        ..close();
      canvas.drawPath(road, Paint()..color = const Color(0x880d1714));
      canvas.save();
      canvas.translate(0, 2);
      canvas.drawPath(road, Paint()..color = const Color(0xff69695f));
      canvas.restore();
      final centerLine = Paint()
        ..color = const Color(0xffe1d1a3)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (final (dc, dr, dx, dy) in const [
        (1, 0, 34.0, 18.0),
        (-1, 0, -34.0, -18.0),
        (0, 1, -34.0, 18.0),
        (0, -1, 34.0, -18.0),
      ]) {
        final nextColumn = b.column + dc, nextRow = b.row + dr;
        final connected = nextColumn >= 0 &&
            nextColumn < columns &&
            nextRow >= 0 &&
            nextRow < rows &&
            roadKeys.contains(nextRow * columns + nextColumn);
        if (connected) {
          canvas.drawLine(
              Offset(c.x, c.y), Offset(c.x + dx, c.y + dy), centerLine);
        }
      }
      return;
    }
    if (b.kind == 8) {
      canvas.drawLine(
          Offset(c.x - 5, c.y + 3),
          Offset(c.x + 28, c.y + 3),
          Paint()
            ..color = const Color(0xff8b6744)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
      for (var plank = 0; plank < 4; plank++) {
        final x = c.x + plank * 7;
        canvas.drawLine(
            Offset(x, c.y - 2),
            Offset(x, c.y + 8),
            Paint()
              ..color = const Color(0xffc49a62)
              ..strokeWidth = 2);
      }
      canvas.drawLine(
          Offset(c.x + 22, c.y - 4),
          Offset(c.x + 22, c.y + 6),
          Paint()
            ..color = const Color(0xffe5d8a6)
            ..strokeWidth = 2);
      return;
    }
    if (b.kind == 11) {
      canvas.drawLine(
          Offset(c.x, c.y + 8),
          Offset(c.x, c.y - 14),
          Paint()
            ..color = const Color(0xffd7d5c8)
            ..strokeWidth = 2);
      final sign = RRect.fromRectAndRadius(
          Rect.fromLTWH(c.x - 10, c.y - 24, 20, 14), const Radius.circular(3));
      canvas.drawRRect(sign, Paint()..color = const Color(0xff246b84));
      canvas.drawRRect(
          sign,
          Paint()
            ..color = const Color(0xffc7edf0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      canvas.drawRect(Rect.fromLTWH(c.x - 5, c.y - 21, 10, 4),
          Paint()..color = const Color(0xfff2d778));
      canvas.drawCircle(Offset(c.x - 5, c.y - 15), 1,
          Paint()..color = const Color(0xffeaf7f7));
      canvas.drawCircle(Offset(c.x + 5, c.y - 15), 1,
          Paint()..color = const Color(0xffeaf7f7));
      return;
    }
    if (b.kind == 4) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(c.x, c.y + 2), width: 41, height: 17),
          Paint()..color = const Color(0xff658c4b));
      canvas.drawCircle(
          Offset(c.x, c.y - 12), 8, Paint()..color = const Color(0xff3d7d43));
      return;
    }
    if (b.kind == 1) {
      final field = Path()
        ..moveTo(c.x - 28, c.y + 7)
        ..lineTo(c.x - 7, c.y - 4)
        ..lineTo(c.x + 10, c.y + 5)
        ..lineTo(c.x - 12, c.y + 17)
        ..close();
      canvas.drawPath(field, Paint()..color = const Color(0xff765532));
      final cropColor = climate.seasonIndex == 3
          ? const Color(0xff9a895d)
          : climate.seasonIndex == 2
              ? const Color(0xffd3b24e)
              : const Color(0xff6e963e);
      final crops = Paint()
        ..color = cropColor
        ..strokeWidth = 1.7;
      for (var line = 0; line < 4; line++) {
        final y = c.y + 3 + line * 3.1;
        canvas.drawLine(Offset(c.x - 24 + line * 1.2, y),
            Offset(c.x - 4 + line * 1.2, y - 10), crops);
      }
    }
    if (b.kind == 9) {
      for (var animal = 0; animal < 3; animal++) {
        final point = Offset(c.x - 20 + animal * 8, c.y + 14);
        canvas.drawOval(
            Rect.fromCenter(center: point, width: 7, height: 5),
            Paint()
              ..color = animal.isEven
                  ? const Color(0xffeee3c7)
                  : const Color(0xff79553b));
        canvas.drawCircle(point + const Offset(3, -1), 2,
            Paint()..color = const Color(0xff2a2924));
      }
    }
    if (b.kind == 10) {
      for (var row = 0; row < 2; row++) {
        for (var crate = 0; crate < 3; crate++) {
          canvas.drawRect(
              Rect.fromLTWH(c.x - 11 + crate * 8, c.y + 5 + row * 6, 6, 5),
              Paint()..color = const Color(0xffb78242));
        }
      }
    }
    final palette = [
      const Color(0xffe4d2a5),
      const Color(0xffc67e4b),
      const Color(0xffb4c3c1),
      const Color(0xffddc27e),
      const Color(0xffc1ad79),
      const Color(0xffbacbd0),
      const Color(0xffd3c19d),
      const Color(0xff80785d),
      const Color(0xff9a754d),
      const Color(0xffb1874f),
    ];
    final base = palette[b.kind.clamp(0, palette.length - 1)];
    final shadow = Path()
      ..moveTo(c.x, c.y - 21)
      ..lineTo(c.x + 23, c.y - 9)
      ..lineTo(c.x, c.y + 3)
      ..lineTo(c.x - 23, c.y - 9)
      ..close();
    canvas.drawPath(shadow, Paint()..color = const Color(0x660d1714));
    final left = Path()
      ..moveTo(c.x - 17, c.y - 15)
      ..lineTo(c.x, c.y - 7)
      ..lineTo(c.x, c.y + 14)
      ..lineTo(c.x - 17, c.y + 5)
      ..close();
    final right = Path()
      ..moveTo(c.x, c.y - 7)
      ..lineTo(c.x + 17, c.y - 15)
      ..lineTo(c.x + 17, c.y + 5)
      ..lineTo(c.x, c.y + 14)
      ..close();
    canvas.drawPath(left, Paint()..color = base);
    canvas.drawPath(
        right, Paint()..color = Color.lerp(base, Colors.black, .2)!);
    final roof = Path()
      ..moveTo(c.x - 20, c.y - 15)
      ..lineTo(c.x, c.y - 28)
      ..lineTo(c.x + 20, c.y - 15)
      ..lineTo(c.x, c.y - 5)
      ..close();
    final roofColor = b.kind == 9
        ? const Color(0xff76563a)
        : b.kind == 10
            ? const Color(0xff996333)
            : const Color(0xff9d4937);
    canvas.drawPath(roof, Paint()..color = roofColor);
    canvas.drawRect(Rect.fromLTWH(c.x - 3, c.y - 2, 6, 12),
        Paint()..color = const Color(0xff563d2b));
    canvas.drawRect(Rect.fromLTWH(c.x - 12, c.y - 8, 5, 5),
        Paint()..color = const Color(0xff75c4ce));
    canvas.drawRect(Rect.fromLTWH(c.x + 7, c.y - 10, 5, 5),
        Paint()..color = const Color(0xff75c4ce));
  }

  void _drawPeople(Canvas canvas) {
    for (final person in people.residents) {
      final p = person.position;
      final bob = math.sin(person.walkPhase) * 1.5;
      final color = switch (person.personality) {
        'builder' => const Color(0xffbf8c59),
        'explorer' => const Color(0xff73ad86),
        'mystic' => const Color(0xffa68bcc),
        _ => const Color(0xffe4bf8e),
      };
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(p.x + 2, p.y + 4), width: 7, height: 3),
          Paint()..color = const Color(0x550d1714));
      canvas.drawCircle(Offset(p.x, p.y - 3 + bob), 2.6,
          Paint()..color = const Color(0xffffd085));
      canvas.drawLine(
          Offset(p.x, p.y),
          Offset(p.x, p.y + 4 + bob),
          Paint()
            ..color = color
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact, required this.game});
  final bool compact;
  final SettlementGame game;
  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12, vertical: compact ? 6 : 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.park, color: Color(0xffffcb56), size: 23),
            const SizedBox(width: 7),
            Expanded(
                child: Text('ОДИН ДВОР — ЦИВИЛИЗАЦИЯ',
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                        fontSize: compact ? 10 : 14))),
            if (!compact)
              ValueListenableBuilder<EconomyMetrics>(
                  valueListenable: game.economy,
                  builder: (context, e, _) =>
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _Resource(
                            icon: Icons.paid,
                            value: e.treasury.toStringAsFixed(0)),
                        _Resource(
                            icon: Icons.grass,
                            value: e.food.toStringAsFixed(0)),
                        _Resource(
                            icon: Icons.forest,
                            value: e.materials.toStringAsFixed(0)),
                        _Resource(
                            icon: Icons.storefront,
                            value: e.goods.toStringAsFixed(0)),
                      ])),
            ValueListenableBuilder<ResidentMetrics>(
                valueListenable: game.residents,
                builder: (context, r, _) => _Resource(
                    icon: Icons.people_alt, value: '${r.population}')),
            if (!compact) ...[
              ValueListenableBuilder<CivilizationSimulation>(
                  valueListenable: game.civilization,
                  builder: (context, civilization, _) => Text(
                      'Год ${civilization.year} · ${civilization.currentEra}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              ValueListenableBuilder<WorldState>(
                  valueListenable: game.worldState,
                  builder: (context, world, _) => Row(children: [
                        Icon(
                            world.weather.toLowerCase().contains('дожд')
                                ? Icons.cloud
                                : world.weather.toLowerCase().contains('снег')
                                    ? Icons.ac_unit
                                    : Icons.wb_sunny,
                            color: const Color(0xffffd05c),
                            size: 18),
                        const SizedBox(width: 3),
                        Text(
                            '${[
                              12,
                              24,
                              9,
                              -4
                            ][world.seasonIndex]}° · ${world.weather}',
                            style: const TextStyle(fontSize: 10)),
                      ])),
              const SizedBox(width: 5),
              _TimeControls(game: game),
            ],
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Сохранить игру',
              onPressed: () => unawaited(game.save()),
              icon: const Icon(Icons.save, size: 19, color: Colors.white70),
            ),
          ]),
          if (!compact) ...[
            const SizedBox(height: 7),
            Row(children: [
              _NavButton(Icons.home_work, 'Строительство',
                  active: true,
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Строительство')),
              _NavButton(Icons.settings_suggest, 'Управление',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Управление')),
              _NavButton(Icons.query_stats, 'Экономика',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Экономика')),
              _NavButton(Icons.groups, 'Население',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Население')),
              _NavButton(Icons.school, 'Образование',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Образование')),
              _NavButton(Icons.health_and_safety, 'Здоровье',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Здоровье')),
              _NavButton(Icons.shield, 'Безопасность',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Безопасность')),
              _NavButton(Icons.theater_comedy, 'Культура',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Культура')),
              _NavButton(Icons.emoji_events, 'Достижения',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Достижения')),
              _NavButton(Icons.public, 'Мир',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Мир')),
              _NavButton(Icons.history, 'Летопись',
                  onPressed: () =>
                      _showCivilizationPanel(context, game, 'Летопись')),
            ]),
          ],
        ]),
      );
}

class _Resource extends StatelessWidget {
  const _Resource({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xffffd05c)),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))
      ]));
}

class _NavButton extends StatelessWidget {
  const _NavButton(this.icon, this.label,
      {this.active = false, this.onPressed});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
              color: active ? const Color(0xff24576a) : const Color(0x99101c24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? const Color(0xff67d5e4) : Colors.white12)),
          child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon,
                    size: 16,
                    color: active ? const Color(0xffffd05c) : Colors.white),
                const SizedBox(width: 4),
                Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700)))
              ]))));
}

void _showCivilizationPanel(
    BuildContext context, SettlementGame game, String title) {
  showDialog<void>(
    context: context,
    builder: (context) => _CivilizationPanel(game: game, title: title),
  );
}

class _CivilizationPanel extends StatefulWidget {
  const _CivilizationPanel({required this.game, required this.title});
  final SettlementGame game;
  final String title;

  @override
  State<_CivilizationPanel> createState() => _CivilizationPanelState();
}

class _CivilizationPanelState extends State<_CivilizationPanel> {
  String? message;

  void _act(String Function() action) {
    final result = action();
    setState(() => message = result);
    widget.game.map.recentEvents.insert(0, result);
    widget.game.refreshFromMap();
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );

  Widget _action(String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: onPressed, child: Text(label)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.game.isLoaded) {
      return AlertDialog(
          title: Text(widget.title), content: const LinearProgressIndicator());
    }
    final map = widget.game.map;
    final civ = map.civilization;
    final people = map.people.residents;
    final economy = map.market;
    final averageHealth = people.isEmpty
        ? 100
        : (people.fold<double>(0, (sum, r) => sum + r.health) /
                people.length *
                100)
            .round();
    final jobs = <String, int>{};
    for (final person in people) {
      final job = person.job ?? 'Распределяется';
      jobs[job] = (jobs[job] ?? 0) + 1;
    }
    final body = switch (widget.title) {
      'Строительство' => <Widget>[
          _line('Построено зданий', '${map._buildings.length}'),
          _line('Стройматериалы', economy.materials.toStringAsFixed(1)),
          const SizedBox(height: 8),
          const Text(
              'Выберите инструмент в нижней панели и нажмите на свободную клетку карты.'),
          for (var i = 0; i < _BuildBar.items.length; i++)
            _line(_BuildBar.items[i].$2,
                '×${map._buildings.where((b) => b.kind == i).length}'),
        ],
      'Управление' => <Widget>[
          _line('Государство', civ.nationName),
          _line('Год государства', '${civ.year}'),
          _line(
              'Правитель',
              people.where((r) => r.id == civ.rulerId).firstOrNull?.name ??
                  'Совет'),
          _line('Поддержка жителей', '${(civ.cityApproval * 100).round()}%'),
          _line('Казна', economy.treasury.toStringAsFixed(0)),
          _line('Армия · земли · слава',
              '${civ.army} · ${civ.territory} · ${civ.prestige.floor()}'),
          _line('Общины · жители в общинах',
              '${civ.factions.length} · ${civ.affiliatedResidents}'),
          _line('Семейные домохозяйства', '${civ.households.length}'),
          _action('Нанять до 5 бойцов · 8 монет за бойца',
              () => _act(() => civ.recruitArmy(economy))),
          _action('Отправить дипломатическую миссию · 12 монет',
              () => _act(() => civ.conductDiplomacy(economy))),
          _action('Начать военный поход · 20 монет',
              () => _act(() => civ.launchCampaign(economy, null))),
          _line('Походы · победы · поражения',
              '${civ.campaigns} · ${civ.victories} · ${civ.defeats}'),
          for (final relation in civ.diplomacy.entries)
            _line(relation.key,
                '${relation.value.round()}%${relation.value >= 80 ? ' · союз' : ''}'),
        ],
      'Экономика' => <Widget>[
          _line('Казна', economy.treasury.toStringAsFixed(0)),
          _line('Доходы торговли', economy.tradeVolume.floor().toString()),
          _line('Еда · материалы · товары',
              '${economy.food.floor()} · ${economy.materials.floor()} · ${economy.goods.floor()}'),
          const SizedBox(height: 10),
          Text('Налог: ${(economy.taxRate * 100).round()}%'),
          Slider(
            value: economy.taxRate.clamp(0, .5),
            min: 0,
            max: .5,
            divisions: 10,
            label: '${(economy.taxRate * 100).round()}%',
            onChanged: (value) {
              civ.setTaxRate(economy, value);
              widget.game.refreshFromMap();
              setState(() {});
            },
          ),
          _line('Мировая торговля', '${civ.worldTradeVolume.floor()}'),
          _line('Фермы · обрабатываемые поля',
              '${map._buildings.where((b) => b.kind == 1).length} · ${map._buildings.where((b) => b.kind == 1).length * 4}'),
          _line('Урожаи · плодородие почвы',
              '${map.climate.nature['harvests']?.floor() ?? 0} · ${map.climate.nature['soil']?.round() ?? 0}%'),
          _line('Рыба · мясо за производственный цикл',
              '${economy.fishProduction.toStringAsFixed(1)} · ${economy.meatProduction.toStringAsFixed(1)}'),
          _line('Склады · вместимость каждого ресурса',
              '${map._buildings.where((b) => b.kind == 10).length} · ${economy.storageCapacity.floor()}'),
          _line('Открытые поселения', '${civ.foundedSettlements}'),
          _line('Переселения', '${civ.migrations}'),
        ],
      'Мир' => <Widget>[
          _line('Поселения · мировая торговля',
              '${civ.foundedSettlements} / ${civ.worldSettlements.length} · ${civ.worldTradeVolume.floor()}'),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _WorldMapPainter(cities: civ.worldSettlements),
            ),
          ),
          const SizedBox(height: 8),
          for (final city in civ.worldSettlements)
            _line(
                '${city.name} · ${city.unlocked ? '${city.population} жителей' : 'закрыто'}',
                city.unlocked
                    ? 'казна ${city.treasury.floor()} · армия ${city.army.floor()}'
                    : 'откроется при ${city.populationThreshold} жителях'),
          _line('Миграции',
              '${civ.migrations} · городам свой бюджет, запасы и оборона'),
          const Divider(),
          const Text('Соседние государства',
              style: TextStyle(fontWeight: FontWeight.w800)),
          for (final state in civ.foreignNations)
            _line('${state.name} · ${state.population} жителей',
                'казна ${state.treasury.floor()} · армия ${state.army} · связь ${state.relation.round()}%'),
        ],
      'Летопись' => <Widget>[
          _line('Записей', '${civ.history.length}'),
          _line('Текущий год · эпоха', '${civ.year} · ${civ.currentEra}'),
          const Divider(),
          if (civ.history.isEmpty)
            const Text('События появятся по мере развития поселения.'),
          for (final entry in civ.history.reversed.take(80))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 17,
                child:
                    Text('${entry.year}', style: const TextStyle(fontSize: 10)),
              ),
              title: Text(entry.text),
              subtitle: Text(entry.category),
            ),
        ],
      'Население' => <Widget>[
          _line('Жителей', '${people.length}'),
          _line('Дети · взрослые · старейшины',
              '${people.where((r) => r.age < 42).length} · ${people.where((r) => r.age >= 42 && r.age < 620).length} · ${people.where((r) => r.age >= 620).length}'),
          _line('Семейные пары',
              '${people.where((r) => r.spouseId != null && r.gender == 'М').length}'),
          _line('Домохозяйства · жилые уровни',
              '${civ.households.length} · ${civ.households.where((h) => h.level > 1).length} многоэтажных'),
          _line('Фракции · участники',
              '${civ.factions.length} · ${civ.affiliatedResidents}'),
          _line('Образованные',
              '${people.where((r) => r.education >= 58).length}'),
          for (final entry in jobs.entries) _line(entry.key, '${entry.value}'),
          const Divider(),
          for (final person in people.take(12))
            _line('${person.name} · ${person.age.floor()} лет',
                '${person.job ?? 'без профессии'} · ${person.wallet.floor()} мон. · дом ${person.homeId ?? '—'}'),
        ],
      'Образование' => <Widget>[
          _line('Школы', '${civ.civicBuildings.contains('Школа') ? 1 : 0}'),
          _line(
              'Колледжи', '${civ.civicBuildings.contains('Колледж') ? 1 : 0}'),
          _line('Университеты',
              '${civ.civicBuildings.contains('Университет') ? 1 : 0}'),
          _line('Ученики', '${people.where((r) => r.age < 42).length}'),
          _line('Образованные жители',
              '${people.where((r) => r.education >= 58).length}'),
          _line('Научные очки',
              '${civ.researchPoints.floor()} / ${civ.technologyLevel >= 6 ? 'максимум' : civ.nextResearchTarget.floor()}'),
          _line('Технологии', '${civ.technologyLevel} / 6'),
          _line('Эпоха', civ.currentEra),
          LinearProgressIndicator(value: civ.researchProgress),
        ],
      'Здоровье' => <Widget>[
          _line('Среднее здоровье', '$averageHealth%'),
          _line('Заболевшие', '${civ.sickCount}'),
          _line('Вспышки · выздоровления · лечение',
              '${civ.outbreaks} · ${civ.recovered} · ${civ.treated}'),
          _line('Больницы и медпункты',
              '${civ.civicBuildings.where((b) => b == 'Больница' || b == 'Медпункт').length}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Профилактика эпидемий'),
            value: civ.preventionEnabled,
            onChanged: (value) => setState(() {
              civ.preventionEnabled = value;
              widget.game.refreshFromMap();
            }),
          ),
        ],
      'Безопасность' => <Widget>[
          _line('Преступления', '${civ.crimes}'),
          _line('Раскрыто', '${civ.crimesResolved}'),
          _line('Пожары', '${civ.fireIncidents}'),
          _line('Предотвращено возгораний', '${civ.firesPrevented}'),
          _line(
              'Полиция',
              civ.civicBuildings.contains('Полицейский участок')
                  ? 'участок открыт'
                  : 'нет участка'),
          _line(
              'Пожарная часть',
              civ.civicBuildings.contains('Пожарная часть')
                  ? 'служба работает'
                  : 'нет службы'),
        ],
      'Культура' => <Widget>[
          _line('Культурный уровень', '${civ.cultureLevel} / 10'),
          _line('Культурные очки', '${civ.culturePoints.floor()}'),
          _line('Традиция', civ.tradition),
          _line('Единство', civ.dominantCulture),
          _line('Памятники · праздники', '${civ.monuments} · ${civ.festivals}'),
          _line('Наследие', civ.heritage.floor().toString()),
          _action(
              civ.festivalCooldown > 0
                  ? 'Праздник через ${civ.festivalCooldown.ceil()} с'
                  : 'Провести городской праздник',
              () => _act(() =>
                  civ.holdFestival(economy, people) ?? 'Праздник проведён')),
        ],
      _ => <Widget>[
          _line('Население', '${people.length} / 100 жителей'),
          _line('Уровень технологий', '${civ.technologyLevel} / 6'),
          _line('Эпоха', civ.currentEra),
          _line('Городские учреждения', '${civ.civicBuildings.length}'),
          _line('Союзы', '${civ.alliances}'),
          for (final milestone in [10, 20, 30, 50, 75, 100])
            _line(
                'Население $milestone',
                people.length >= milestone
                    ? 'достигнуто'
                    : '${people.length} / $milestone'),
          _line('Военные победы', '${civ.victories}'),
          _line('Городские праздники', '${civ.festivals}'),
        ],
    };

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...body,
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(message!,
                    style: const TextStyle(color: Color(0xffffd05c))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'))
      ],
    );
  }
}

class _LeftDashboard extends StatelessWidget {
  const _LeftDashboard({required this.game});
  final SettlementGame game;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Column(children: [
        ValueListenableBuilder<ResidentMetrics>(
            valueListenable: game.residents,
            builder: (context, r, _) => _InfoCard(
                    title: 'ЖИТЕЛИ ГОРОДА',
                    icon: Icons.people_alt,
                    rows: [
                      'Население       ${r.population}',
                      'Дети                   ${r.children}',
                      'Взрослые              ${r.adults}',
                      'Старейшины           ${r.elders}',
                      'Семьи                  ${r.couples}',
                      'Поколения         ${r.generations}'
                    ])),
        const SizedBox(height: 8),
        ValueListenableBuilder<EconomyMetrics>(
            valueListenable: game.economy,
            builder: (context, e, _) =>
                _InfoCard(title: 'ЭКОНОМИКА', icon: Icons.paid, rows: [
                  'Казна                 ${e.treasury.toStringAsFixed(0)}',
                  'Еда                     ${e.food.toStringAsFixed(1)}',
                  'Материалы       ${e.materials.toStringAsFixed(1)}',
                  'Товары                 ${e.goods.toStringAsFixed(1)}',
                  'Налог                   ${(e.taxRate * 100).toStringAsFixed(0)}%'
                ])),
        const SizedBox(height: 8),
        ValueListenableBuilder<WorldState>(
            valueListenable: game.worldState,
            builder: (context, w, _) => _InfoCard(
                    title: 'ПРИРОДА И ЭКОЛОГИЯ',
                    icon: Icons.forest,
                    rows: [
                      'Лес                   ${w.nature['forest']!.toStringAsFixed(0)}%',
                      'Животные           ${w.nature['wildlife']!.toStringAsFixed(0)}%',
                      'Плодородие        ${w.nature['soil']!.toStringAsFixed(0)}%',
                      'Загрязнение       ${w.nature['pollution']!.toStringAsFixed(0)}%',
                      'Погода               ${w.weather}'
                    ])),
      ]));
}

class _DistrictPanel extends StatelessWidget {
  const _DistrictPanel({required this.game});
  final SettlementGame game;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<int>>(
      valueListenable: game.districtShares,
      builder: (context, shares, _) => _GlassPanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Row(children: [
                  Icon(Icons.map, color: Color(0xffffcb56), size: 18),
                  SizedBox(width: 6),
                  Text('РАЙОНЫ ГОРОДА',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w800))
                ]),
                const SizedBox(height: 9),
                for (final item in [
                  (Color(0xff2196f3), 'Жилой район', '${shares[0]}%'),
                  (Color(0xffffc107), 'Торговый район', '${shares[1]}%'),
                  (Color(0xffff8f00), 'Производство', '${shares[2]}%'),
                  (Color(0xff4caf50), 'Зелёный район', '${shares[3]}%')
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: item.$1,
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(item.$2,
                                style: const TextStyle(fontSize: 10))),
                        Text(item.$3,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold))
                      ])),
                Container(
                    height: 98,
                    decoration: BoxDecoration(
                        color: const Color(0xff264d40),
                        borderRadius: BorderRadius.circular(9)),
                    child: CustomPaint(
                        painter: _MiniMapPainter(),
                        child: const SizedBox.expand())),
              ])));
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roads = Paint()
      ..color = const Color(0xff438b73)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (.1 + i * .14);
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.width * .17, size.height), roads);
    }
    final river = Path()
      ..moveTo(size.width * .88, 0)
      ..quadraticBezierTo(
          size.width * .55, size.height * .45, size.width, size.height);
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xff3b99bb)
          ..strokeWidth = 13
          ..style = PaintingStyle.stroke);
    final district = Rect.fromLTWH(size.width * .27, size.height * .2,
        size.width * .42, size.height * .52);
    canvas.drawRect(district, Paint()..color = const Color(0x6693c5ff));
    canvas.drawRect(
        district,
        Paint()
          ..color = const Color(0xffbceeff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({required this.events});
  final ValueListenable<List<String>> events;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<String>>(
        valueListenable: events,
        builder: (context, items, _) => _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.notifications_active,
                    color: Color(0xffffd05c), size: 17),
                SizedBox(width: 6),
                Text('СОБЫТИЯ И УВЕДОМЛЕНИЯ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))
              ]),
              const SizedBox(height: 7),
              if (items.isEmpty)
                const Text('🌱  Поселение развивается',
                    style: TextStyle(fontSize: 10))
              else
                for (final event in items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(event,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10)),
                  ),
            ],
          ),
        ),
      );
}

class _TimeControls extends StatelessWidget {
  const _TimeControls({required this.game});
  final SettlementGame game;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder<bool>(
          valueListenable: game.pauseState,
          builder: (context, paused, _) => IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: paused ? 'Продолжить' : 'Пауза',
            onPressed: game.togglePause,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                size: 20, color: const Color(0xffffd05c)),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: game.speedIndex,
          builder: (context, index, _) => TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: Size.zero),
            onPressed: game.cycleSpeed,
            child: Text('×${SettlementGame.speeds[index].toInt()}',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
      ]);
}

class _TechnologyPanel extends StatelessWidget {
  const _TechnologyPanel({required this.civilization});
  final ValueListenable<CivilizationSimulation> civilization;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 218,
      child: ValueListenableBuilder<CivilizationSimulation>(
          valueListenable: civilization,
          builder: (context, state, _) => _GlassPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Row(children: [
                      Icon(Icons.science, color: Color(0xff6ed6ff), size: 18),
                      SizedBox(width: 6),
                      Text('ТЕХНОЛОГИИ',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        'Уровень: ${state.technologyLevel} из 6 · ${state.currentEra}',
                        style: const TextStyle(fontSize: 10)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                        value: state.researchProgress,
                        minHeight: 6,
                        color: Color(0xff4ade80),
                        backgroundColor: Colors.white24),
                    const SizedBox(height: 7),
                    Text(
                        state.technologyLevel >= 6
                            ? 'Максимальный уровень технологий'
                            : 'Наука: ${state.researchPoints.floor()} / ${state.nextResearchTarget.floor()}',
                        style: const TextStyle(fontSize: 10)),
                  ]))));
}

class _CompactStats extends StatelessWidget {
  const _CompactStats({required this.game});
  final SettlementGame game;
  @override
  Widget build(BuildContext context) => _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Row(children: [
        ValueListenableBuilder<ResidentMetrics>(
            valueListenable: game.residents,
            builder: (context, r, _) => Text('👥 ${r.population}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold))),
        const SizedBox(width: 10),
        ValueListenableBuilder<EconomyMetrics>(
            valueListenable: game.economy,
            builder: (context, e, _) => Text(
                '🌾 ${e.food.toStringAsFixed(0)}   🪵 ${e.materials.toStringAsFixed(0)}   🪙 ${e.treasury.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold))),
      ]));
}

class _BuildBar extends StatelessWidget {
  const _BuildBar(
      {required this.compact, required this.selected, required this.onSelect});
  final bool compact;
  final int selected;
  final ValueChanged<int> onSelect;
  static const items = [
    (Icons.home_work, 'Жилые дома'),
    (Icons.agriculture, 'Фермы'),
    (Icons.storefront, 'Торговля'),
    (Icons.add_road, 'Инфраструктура'),
    (Icons.park, 'Парки и отдых'),
    (Icons.shield, 'Службы'),
    (Icons.account_balance, 'Уникальные здания'),
    (Icons.alt_route, 'Дороги'),
    (Icons.set_meal, 'Рыболовство'),
    (Icons.pets, 'Скот'),
    (Icons.warehouse, 'Склады'),
    (Icons.directions_bus, 'Остановки'),
  ];
  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: EdgeInsets.all(compact ? 5 : 8),
        child: Row(children: [
          if (!compact)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('СТРОИТЕЛЬСТВО',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: Color(0xffffd05c),
                  )),
            ),
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: selected == i
                      ? const Color(0xff245a70)
                      : const Color(0xff172c34),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(items[i].$1,
                            color: selected == i
                                ? const Color(0xffffd05c)
                                : Colors.white,
                            size: compact ? 17 : 22),
                        if (!compact) ...[
                          const SizedBox(height: 3),
                          Text(items[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9)),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.pause_circle_filled,
              color: Color(0xffffd05c), size: 28),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<String> rows;
  @override
  Widget build(BuildContext context) => _GlassPanel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xffffcd55), size: 17),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: .4))
        ]),
        const Divider(height: 14, color: Colors.white24),
        for (final row in rows)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(row, style: const TextStyle(fontSize: 10))),
      ]));
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel(
      {required this.child, this.padding = const EdgeInsets.all(11)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
      padding: padding,
      decoration: BoxDecoration(
          color: const Color(0xe9152428),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xff66848a)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: child);
}

class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter({required this.cities});
  final List<WorldSettlementState> cities;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(bounds, const Radius.circular(12));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff729e6c), Color(0xff365c4e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
    );
    for (var i = 0; i < 22; i++) {
      final x = ((i * 73 + 19) % 101) / 100 * size.width;
      final y = ((i * 47 + 13) % 97) / 100 * size.height;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), width: 9 + i % 5 * 5, height: 5 + i % 4 * 3),
        Paint()
          ..color =
              i.isEven ? const Color(0x2234442b) : const Color(0x22e2cf8a),
      );
    }
    final river = Path()
      ..moveTo(size.width * .02, size.height * .12)
      ..cubicTo(size.width * .3, size.height * .24, size.width * .27,
          size.height * .67, size.width * .56, size.height * .48)
      ..cubicTo(size.width * .76, size.height * .34, size.width * .78,
          size.height * .8, size.width * 1.03, size.height * .9);
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0xff428fb4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(12, size.width * .045)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      river,
      Paint()
        ..color = const Color(0x779bd5df)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final openCities = cities.where((city) => city.unlocked).toList();
    final road = Paint()
      ..color = const Color(0xffd7c394)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < openCities.length; i++) {
      final a = Offset(
          openCities[i - 1].x * size.width, openCities[i - 1].y * size.height);
      final b =
          Offset(openCities[i].x * size.width, openCities[i].y * size.height);
      canvas.drawLine(a, b, road);
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = const Color(0x99fff0cb)
            ..strokeWidth = .7);
    }
    for (final city in cities) {
      final center = Offset(city.x * size.width, city.y * size.height);
      if (!city.unlocked) {
        final outline = Paint()
          ..color = const Color(0x99f2e9c8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        for (var segment = 0; segment < 8; segment++) {
          canvas.drawArc(Rect.fromCircle(center: center, radius: 8),
              segment * math.pi / 4, math.pi / 8, false, outline);
        }
        continue;
      }
      final capital = city.isCapital;
      final radius = capital ? 11.0 : 8.0;
      canvas.drawCircle(center + const Offset(0, 2), radius + 2,
          Paint()..color = const Color(0x660f2119));
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color =
                capital ? const Color(0xffffd05c) : const Color(0xffe9ead4));
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = const Color(0xff394c3e)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      canvas.drawRect(
          Rect.fromCenter(
              center: center.translate(-2, -1), width: 4, height: 6),
          Paint()..color = const Color(0xff557c68));
      canvas.drawRect(
          Rect.fromCenter(center: center.translate(3, -2), width: 4, height: 8),
          Paint()..color = const Color(0xff8aa181));
      final label = TextPainter(
        text: TextSpan(
          text: city.name,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 100);
      label.paint(canvas, Offset(center.dx - label.width / 2, center.dy + 10));
      final population = TextPainter(
        text: TextSpan(
          text: '👥 ${city.population}',
          style: const TextStyle(color: Color(0xfff7e9bd), fontSize: 7),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      population.paint(
          canvas, Offset(center.dx - population.width / 2, center.dy + 20));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WorldMapPainter oldDelegate) => true;
}

