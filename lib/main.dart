import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game/isometric_grid.dart';
import 'game/resident_simulation.dart';

void main() => runApp(const OneYardApp());

class OneYardApp extends StatelessWidget {
  const OneYardApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Один двор — цивилизация',
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

class _SettlementScreenState extends State<SettlementScreen> {
  late final SettlementGame game;
  double _previousScale = 1;
  int _selectedTool = 0;

  @override
  void initState() {
    super.initState();
    game = SettlementGame();
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
                  child: GameWidget(game: game),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 8,
                child:
                    _TopBar(compact: compact, population: game.residentCount),
              ),
              if (!compact)
                Positioned(
                    left: 12,
                    top: 122,
                    bottom: 118,
                    width: 222,
                    child: _SidePanel(population: game.residentCount)),
              if (!compact)
                const Positioned(
                    right: 12, top: 122, width: 218, child: _RightPanel()),
              if (!compact)
                const Positioned(
                    left: 12, bottom: 112, width: 390, child: _EventsPanel()),
              if (!compact)
                const Positioned(
                    right: 12,
                    bottom: 112,
                    width: 218,
                    child: _ResearchPanel()),
              Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _BuildBar(
                    compact: compact,
                    selected: _selectedTool,
                    onSelect: (index) => setState(() => _selectedTool = index),
                    onBuild: () => setState(() {
                      game.map.addBuilding(_selectedTool);
                    }),
                  )),
              if (compact)
                Positioned(
                    left: 12, right: 12, top: 70, child: const _CompactStats()),
            ]);
          }),
        ),
      );
}

class SettlementGame extends FlameGame {
  late final SettlementMap map;
  final ValueNotifier<int> residentCount = ValueNotifier<int>(8);
  double _refreshTimer = 0;

  @override
  Color backgroundColor() => const Color(0xff183b3b);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.zoom = 0.82;
    map = SettlementMap();
    world.add(map);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _refreshTimer += dt;
    if (_refreshTimer >= 0.5 && isLoaded) {
      _refreshTimer = 0;
      residentCount.value = map.people.residents.length;
    }
  }

  @override
  void onRemove() {
    residentCount.dispose();
    super.onRemove();
  }

  void pan(double dx, double dy) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position.add(Vector2(-dx / zoom, -dy / zoom));
  }

  void zoom(double factor) {
    if (!factor.isFinite || factor <= 0) return;
    camera.viewfinder.zoom = (camera.viewfinder.zoom * factor).clamp(0.45, 2.2);
  }
}

class _Building {
  const _Building(this.column, this.row, this.kind);
  final int column;
  final int row;
  final int kind;
}

class SettlementMap extends Component {
  static const columns = 28;
  static const rows = 24;
  static const tileW = 68.0;
  static const tileH = 36.0;
  double _timeOfDay = 0.35;
  late final ResidentSimulation people = ResidentSimulation.initial(
    sites: [
      for (final building in _buildings)
        ResidentSite(
          position: IsometricPoint(
            (building.column - building.row) * tileW / 2,
            (building.column + building.row) * tileH / 2,
          ),
          role: _roleForKind(building.kind),
        ),
      ResidentSite(position: _center(23, 12).asPoint(), role: 'источник воды'),
      ResidentSite(position: _center(5, 18).asPoint(), role: 'парк отдыха'),
    ],
    width: tileW * columns,
    height: tileH * rows,
  );
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

  void addBuilding(int kind) {
    final index = _buildings.length;
    final building =
        _Building(3 + (index * 7) % 22, 4 + (index * 5) % 16, kind % 4);
    _buildings.add(building);
    people.sites.add(ResidentSite(
      position: _center(building.column, building.row).asPoint(),
      role: _roleForKind(building.kind),
    ));
  }

  static String _roleForKind(int kind) => switch (kind) {
        0 => 'дом',
        1 => 'ферма',
        2 => 'рынок',
        _ => 'совет',
      };

  Vector2 _center(int column, int row) => Vector2(
        (column - row) * tileW / 2,
        (column + row) * tileH / 2,
      );

  @override
  void update(double dt) {
    _timeOfDay = (_timeOfDay + dt / 180) % 1;
    final hour = (_timeOfDay * 24).floor();
    final isNight = hour < 6 || hour >= 20;
    people.update(dt, isNight: isNight);
  }

  @override
  void render(Canvas canvas) {
    final origin = _center(columns ~/ 2, rows ~/ 2);
    canvas.save();
    canvas.translate(-origin.x, -origin.y);
    _drawGround(canvas);
    _drawRoads(canvas);
    _drawRiver(canvas);
    _drawTrees(canvas);
    final sorted = [..._buildings]
      ..sort((a, b) => (a.column + a.row).compareTo(b.column + b.row));
    for (final building in sorted) {
      _drawBuilding(canvas, building);
    }
    _drawPeople(canvas);
    canvas.restore();
  }

  void _drawGround(Canvas canvas) {
    final p = Paint()..style = PaintingStyle.fill;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final c = _center(col, row);
        final path = Path()
          ..moveTo(c.x, c.y - tileH / 2)
          ..lineTo(c.x + tileW / 2, c.y)
          ..lineTo(c.x, c.y + tileH / 2)
          ..lineTo(c.x - tileW / 2, c.y)
          ..close();
        final shade = ((col * 19 + row * 13) % 8) / 100;
        p.color = Color.lerp(
            const Color(0xff54834c), const Color(0xff92a65b), shade)!;
        canvas.drawPath(path, p);
        p.color = const Color(0x2276a75b);
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = p.color);
      }
    }
  }

  void _drawRoads(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xff80785d)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xffc5b688)
      ..strokeWidth = 2;
    for (final row in [8, 13, 18]) {
      final a = _center(1, row);
      final b = _center(columns - 2, row);
      canvas.drawLine(a.toOffset(), b.toOffset(), paint);
      canvas.drawLine(a.toOffset(), b.toOffset(), edge);
    }
    for (final col in [7, 13, 19]) {
      final a = _center(col, 1);
      final b = _center(col, rows - 2);
      canvas.drawLine(a.toOffset(), b.toOffset(), paint);
      canvas.drawLine(a.toOffset(), b.toOffset(), edge);
    }
    final center = _center(13, 13);
    canvas.drawCircle(
        center.toOffset(), 21, Paint()..color = const Color(0xffb7a878));
    canvas.drawCircle(
        center.toOffset(), 14, Paint()..color = const Color(0xff4daec2));
    canvas.drawCircle(
        center.toOffset(), 5, Paint()..color = const Color(0xffd9f7e8));
  }

  void _drawRiver(Canvas canvas) {
    final river = Path();
    for (var i = 0; i < 24; i++) {
      final point = _center(24 + (i % 3 == 0 ? 1 : 0), i);
      if (i == 0) {
        river.moveTo(point.x, point.y);
      } else {
        river.lineTo(point.x, point.y);
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
        final c = _center(col, row);
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

  void _drawBuilding(Canvas canvas, _Building building) {
    final c = _center(building.column, building.row);
    final colors = [
      const Color(0xffe4d2a5),
      const Color(0xffc67e4b),
      const Color(0xffb4c3c1),
      const Color(0xffddc27e)
    ];
    final base = colors[building.kind];
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
    canvas.drawPath(
        roof,
        Paint()
          ..color = building.kind == 3
              ? const Color(0xff85939a)
              : const Color(0xff9d4937));
    canvas.drawRect(Rect.fromLTWH(c.x - 3, c.y - 2, 6, 12),
        Paint()..color = const Color(0xff563d2b));
    canvas.drawRect(Rect.fromLTWH(c.x - 12, c.y - 8, 5, 5),
        Paint()..color = const Color(0xff75c4ce));
    canvas.drawRect(Rect.fromLTWH(c.x + 7, c.y - 10, 5, 5),
        Paint()..color = const Color(0xff75c4ce));
  }

  void _drawPeople(Canvas canvas) {
    for (final resident in people.residents) {
      final c = resident.position;
      final bob = math.sin(resident.walkPhase) * 1.5;
      final color = switch (resident.personality) {
        'builder' => const Color(0xffbf8c59),
        'explorer' => const Color(0xff73ad86),
        'mystic' => const Color(0xffa68bcc),
        _ => const Color(0xffe4bf8e),
      };
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.x + 2, c.y + 4), width: 7, height: 3),
          Paint()..color = const Color(0x550d1714));
      canvas.drawCircle(Offset(c.x, c.y - 3 + bob), 2.6,
          Paint()..color = const Color(0xffffd085));
      canvas.drawLine(
          Offset(
            c.x,
            c.y,
          ),
          Offset(c.x, c.y + 4 + bob),
          Paint()
            ..color = color
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact, required this.population});
  final bool compact;
  final ValueListenable<int> population;
  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 14, vertical: compact ? 7 : 9),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.park, color: Color(0xffffcb56), size: 24),
            const SizedBox(width: 8),
            Expanded(
                child: Text('ОДИН ДВОР — ЦИВИЛИЗАЦИЯ',
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                        fontSize: compact ? 11 : 15))),
            if (!compact) ...[
              const _Resource(icon: Icons.currency_bitcoin, value: '258 750'),
              const _Resource(icon: Icons.grass, value: '12 860'),
              const _Resource(icon: Icons.forest, value: '8 420'),
              const _Resource(icon: Icons.view_in_ar, value: '5 720'),
              const _Resource(icon: Icons.bolt, value: '3 240'),
              const _Resource(icon: Icons.people_alt, value: '45 230'),
            ] else
              ValueListenableBuilder<int>(
                valueListenable: population,
                builder: (context, count, _) =>
                    _Resource(icon: Icons.people_alt, value: '$count'),
              ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Icon(Icons.calendar_month, size: 19, color: Colors.white70),
              const SizedBox(width: 5),
              const Text('Год 1  ·  Весна',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.wb_sunny, color: Color(0xffffd05c), size: 20),
              const SizedBox(width: 4),
              const Text('+16°'),
              const SizedBox(width: 10),
              const Icon(Icons.pause, size: 22, color: Colors.white70),
              const Icon(Icons.fast_forward,
                  size: 22, color: Color(0xffffd05c)),
            ],
            const SizedBox(width: 5),
            const Icon(Icons.settings, size: 21, color: Colors.white70),
          ]),
          if (!compact) ...[
            const SizedBox(height: 8),
            Row(children: const [
              _NavButton(
                  icon: Icons.home_work, label: 'Строительство', active: true),
              _NavButton(icon: Icons.settings_suggest, label: 'Управление'),
              _NavButton(icon: Icons.query_stats, label: 'Экономика'),
              _NavButton(icon: Icons.groups, label: 'Население'),
              _NavButton(icon: Icons.school, label: 'Образование'),
              _NavButton(icon: Icons.health_and_safety, label: 'Здоровье'),
              _NavButton(icon: Icons.shield, label: 'Безопасность'),
              _NavButton(icon: Icons.theater_comedy, label: 'Культура'),
              _NavButton(icon: Icons.emoji_events, label: 'Достижения'),
            ]),
          ],
        ]),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton(
      {required this.icon, required this.label, this.active = false});
  final IconData icon;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: active ? const Color(0xff24576a) : const Color(0x99101c24),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: active ? const Color(0xff67d5e4) : Colors.white12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 17,
                color: active ? const Color(0xffffd05c) : Colors.white),
            const SizedBox(width: 5),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
        ),
      ));
}

class _Resource extends StatelessWidget {
  const _Resource({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(children: [
          Icon(icon, size: 17, color: const Color(0xffffd05c)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.population});
  final ValueListenable<int> population;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Column(children: [
        ValueListenableBuilder<int>(
            valueListenable: population,
            builder: (context, count, _) => _InfoCard(
                    title: 'ЖИТЕЛИ ГОРОДА',
                    icon: Icons.people_alt,
                    rows: [
                      'Население        $count',
                      'Поведение          активно',
                      'Счастье                 68%',
                      'Занятость           считать',
                      'Образование            0%',
                      'Здоровье              100%'
                    ])),
        const SizedBox(height: 9),
        _InfoCard(title: 'ЭКОНОМИКА', icon: Icons.paid, rows: [
          'Бюджет           258 750',
          'Доход       +12 430/день',
          'Расход       −11 820/день',
          'Налог                 12%'
        ]),
        SizedBox(height: 9),
        _InfoCard(title: 'ПРИРОДА И ЭКОЛОГИЯ', icon: Icons.forest, rows: [
          'Лес                   62%',
          'Чистота              92%',
          'Плодородие           78%',
          'Загрязнение          12%'
        ]),
      ]));
}

class _RightPanel extends StatelessWidget {
  const _RightPanel();
  @override
  Widget build(BuildContext context) => _GlassPanel(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.map, color: Color(0xffffcb56), size: 18),
            SizedBox(width: 7),
            Text('РАЙОНЫ ГОРОДА',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))
          ]),
          const SizedBox(height: 10),
          for (final row in const [
            (Color(0xff2196f3), 'Жилой район', '35%'),
            (Color(0xffffc107), 'Торговый район', '22%'),
            (Color(0xffff8f00), 'Промышленный', '20%'),
            (Color(0xff4caf50), 'Зелёный район', '23%')
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: row.$1,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 7),
                  Expanded(
                      child:
                          Text(row.$2, style: const TextStyle(fontSize: 11))),
                  Text(row.$3,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))
                ])),
          const SizedBox(height: 4),
          Container(
              height: 100,
              decoration: BoxDecoration(
                  color: const Color(0xff264d40),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24)),
              child: CustomPaint(
                  painter: _MiniMapPainter(), child: const SizedBox.expand())),
        ],
      ));
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff438b73);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (.12 + i * .12);
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.width * .18, size.height), p);
    }
    final river = Path()
      ..moveTo(size.width * .88, 0)
      ..quadraticBezierTo(
          size.width * .55, size.height * .45, size.width, size.height);
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xff3b99bb)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke);
    canvas.drawRect(
        Rect.fromLTWH(size.width * .28, size.height * .22, size.width * .43,
            size.height * .5),
        Paint()..color = const Color(0x6693c5ff));
    canvas.drawRect(
        Rect.fromLTWH(size.width * .28, size.height * .22, size.width * .43,
            size.height * .5),
        Paint()
          ..color = const Color(0xffbceeff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel();
  @override
  Widget build(BuildContext context) => _GlassPanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
            Row(children: [
              Icon(Icons.notifications_active,
                  color: Color(0xffffd05c), size: 17),
              SizedBox(width: 6),
              Text('СОБЫТИЯ И УВЕДОМЛЕНИЯ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))
            ]),
            SizedBox(height: 7),
            Text('🌾  Урожай зерна собран: +1 240 т',
                style: TextStyle(fontSize: 10)),
            SizedBox(height: 4),
            Text('🔬  Открыто новое исследование',
                style: TextStyle(fontSize: 10)),
            SizedBox(height: 4),
            Text('🔥  В городе вспыхнул пожар', style: TextStyle(fontSize: 10)),
          ]));
}

class _ResearchPanel extends StatelessWidget {
  const _ResearchPanel();
  @override
  Widget build(BuildContext context) => _GlassPanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
            Row(children: [
              Icon(Icons.science, color: Color(0xff6ed6ff), size: 18),
              SizedBox(width: 6),
              Text('ТЕХНОЛОГИИ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))
            ]),
            SizedBox(height: 8),
            Text('Уровень: 3 из 6', style: TextStyle(fontSize: 11)),
            SizedBox(height: 6),
            LinearProgressIndicator(
                value: .62,
                minHeight: 7,
                color: Color(0xff4ade80),
                backgroundColor: Colors.white24),
            SizedBox(height: 8),
            Text('⚛  Наука: 2 340', style: TextStyle(fontSize: 11)),
          ]));
}

class _CompactStats extends StatelessWidget {
  const _CompactStats();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: _GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text('🌱 Весна  ·  Год 1       👥 72       🌲 72%',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: const Color(0xffffcd55), size: 18),
            const SizedBox(width: 7),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: .5))
          ]),
          const Divider(height: 16, color: Colors.white24),
          for (final row in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(row, style: const TextStyle(fontSize: 12))),
        ]),
      );
}

class _BuildBar extends StatelessWidget {
  const _BuildBar(
      {required this.compact,
      required this.selected,
      required this.onSelect,
      required this.onBuild});
  final bool compact;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onBuild;
  static const items = [
    (Icons.home_work, 'Жильё'),
    (Icons.factory, 'Производство'),
    (Icons.storefront, 'Торговля'),
    (Icons.add_road, 'Инфраструктура'),
    (Icons.park, 'Парки'),
    (Icons.shield, 'Службы'),
    (Icons.account_balance, 'Уникальные'),
    (Icons.alt_route, 'Дороги'),
  ];
  @override
  Widget build(BuildContext context) => _GlassPanel(
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Row(children: [
          if (!compact)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('СТРОИТЕЛЬСТВО',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Color(0xffffd05c)))),
          for (var i = 0; i < items.length; i++)
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: selected == i
                    ? const Color(0xff245a70)
                    : const Color(0xff172c34),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    onSelect(i);
                    onBuild();
                  },
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: compact ? 9 : 11),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(items[i].$1,
                            color: selected == i
                                ? const Color(0xffffd05c)
                                : Colors.white,
                            size: compact ? 19 : 23),
                        if (!compact) ...[
                          const SizedBox(height: 3),
                          Text(items[i].$2,
                              style: const TextStyle(fontSize: 10))
                        ],
                      ])),
                ),
              ),
            )),
          const SizedBox(width: 6),
          const Icon(Icons.pause_circle_filled,
              color: Color(0xffffd05c), size: 30),
        ]),
      );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel(
      {required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xe9152428),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xff66848a), width: 1),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: child,
      );
}

extension _Vector2IsometricPoint on Vector2 {
  IsometricPoint asPoint() => IsometricPoint(x, y);
}
