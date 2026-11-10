import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
            seedColor: const Color(0xffe5ad39), brightness: Brightness.dark,
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
                    game.pan(details.focalPointDelta.dx, details.focalPointDelta.dy);
                    if (details.pointerCount > 1) game.zoom(factor);
                  },
                  child: GameWidget(game: game),
                ),
              ),
              Positioned(
                left: 12, right: 12, top: 10,
                child: _TopBar(compact: compact),
              ),
              if (!compact)
                Positioned(left: 12, top: 78, bottom: 100, width: 220,
                  child: const _SidePanel()),
              Positioned(left: 12, right: 12, bottom: 12,
                child: _BuildBar(
                  compact: compact,
                  selected: _selectedTool,
                  onSelect: (index) => setState(() => _selectedTool = index),
                  onBuild: () => setState(() {
                    game.map.addBuilding(_selectedTool);
                  }),
                )),
              if (compact)
                Positioned(left: 12, right: 12, top: 70,
                  child: const _CompactStats()),
            ]);
          }),
        ),
      );
}

class SettlementGame extends FlameGame {
  late final SettlementMap map;

  @override
  Color backgroundColor() => const Color(0xff183b3b);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.zoom = 0.82;
    map = SettlementMap();
    world.add(map);
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
  final List<_Building> _buildings = [
    const _Building(13, 10, 3), const _Building(10, 12, 0),
    const _Building(16, 12, 1), const _Building(12, 15, 2),
    const _Building(18, 15, 0), const _Building(8, 9, 1),
    const _Building(20, 10, 2), const _Building(15, 7, 0),
    const _Building(6, 14, 0), const _Building(21, 17, 1),
  ];

  void addBuilding(int kind) {
    final index = _buildings.length;
    _buildings.add(_Building(3 + (index * 7) % 22, 4 + (index * 5) % 16, kind % 4));
  }

  Vector2 _center(int column, int row) => Vector2(
        (column - row) * tileW / 2,
        (column + row) * tileH / 2,
      );

  @override
  void render(Canvas canvas) {
    final origin = _center(columns ~/ 2, rows ~/ 2);
    canvas.save();
    canvas.translate(-origin.x, -origin.y);
    _drawGround(canvas);
    _drawRoads(canvas);
    _drawRiver(canvas);
    _drawTrees(canvas);
    final sorted = [..._buildings]..sort((a, b) => (a.column + a.row).compareTo(b.column + b.row));
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
        p.color = Color.lerp(const Color(0xff54834c), const Color(0xff92a65b), shade)!;
        canvas.drawPath(path, p);
        p.color = const Color(0x2276a75b);
        canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = p.color);
      }
    }
  }

  void _drawRoads(Canvas canvas) {
    final paint = Paint()..color = const Color(0xff80785d)..strokeWidth = 15..strokeCap = StrokeCap.round;
    final edge = Paint()..color = const Color(0xffc5b688)..strokeWidth = 2;
    for (final row in [8, 13, 18]) {
      final a = _center(1, row); final b = _center(columns - 2, row);
      canvas.drawLine(a.toOffset(), b.toOffset(), paint);
      canvas.drawLine(a.toOffset(), b.toOffset(), edge);
    }
    for (final col in [7, 13, 19]) {
      final a = _center(col, 1); final b = _center(col, rows - 2);
      canvas.drawLine(a.toOffset(), b.toOffset(), paint);
      canvas.drawLine(a.toOffset(), b.toOffset(), edge);
    }
    final center = _center(13, 13);
    canvas.drawCircle(center.toOffset(), 21, Paint()..color = const Color(0xffb7a878));
    canvas.drawCircle(center.toOffset(), 14, Paint()..color = const Color(0xff4daec2));
    canvas.drawCircle(center.toOffset(), 5, Paint()..color = const Color(0xffd9f7e8));
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
    canvas.drawPath(river, Paint()..color = const Color(0x994ec1d1)..strokeWidth = 30..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawPath(river, Paint()..color = const Color(0xff64c7d0)..strokeWidth = 19..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  void _drawTrees(Canvas canvas) {
    for (var row = 1; row < rows; row += 3) {
      for (var col = 1; col < columns; col += 3) {
        if ((col * 3 + row * 5) % 7 < 3 || col > 22) continue;
        final c = _center(col, row);
        canvas.drawOval(Rect.fromCenter(center: Offset(c.x + 3, c.y + 5), width: 23, height: 10), Paint()..color = const Color(0x550f241b));
        canvas.drawRect(Rect.fromLTWH(c.x - 2, c.y - 10, 4, 15), Paint()..color = const Color(0xff72563b));
        canvas.drawCircle(Offset(c.x, c.y - 14), 10, Paint()..color = const Color(0xff316c3b));
        canvas.drawCircle(Offset(c.x - 4, c.y - 17), 5, Paint()..color = const Color(0xff559148));
      }
    }
  }

  void _drawBuilding(Canvas canvas, _Building building) {
    final c = _center(building.column, building.row);
    final colors = [const Color(0xffe4d2a5), const Color(0xffc67e4b), const Color(0xffb4c3c1), const Color(0xffddc27e)];
    final base = colors[building.kind];
    final shadow = Path()..moveTo(c.x, c.y - 21)..lineTo(c.x + 23, c.y - 9)..lineTo(c.x, c.y + 3)..lineTo(c.x - 23, c.y - 9)..close();
    canvas.drawPath(shadow, Paint()..color = const Color(0x660d1714));
    final left = Path()..moveTo(c.x - 17, c.y - 15)..lineTo(c.x, c.y - 7)..lineTo(c.x, c.y + 14)..lineTo(c.x - 17, c.y + 5)..close();
    final right = Path()..moveTo(c.x, c.y - 7)..lineTo(c.x + 17, c.y - 15)..lineTo(c.x + 17, c.y + 5)..lineTo(c.x, c.y + 14)..close();
    canvas.drawPath(left, Paint()..color = base);
    canvas.drawPath(right, Paint()..color = Color.lerp(base, Colors.black, .2)!);
    final roof = Path()..moveTo(c.x - 20, c.y - 15)..lineTo(c.x, c.y - 28)..lineTo(c.x + 20, c.y - 15)..lineTo(c.x, c.y - 5)..close();
    canvas.drawPath(roof, Paint()..color = building.kind == 3 ? const Color(0xff85939a) : const Color(0xff9d4937));
    canvas.drawRect(Rect.fromLTWH(c.x - 3, c.y - 2, 6, 12), Paint()..color = const Color(0xff563d2b));
    canvas.drawRect(Rect.fromLTWH(c.x - 12, c.y - 8, 5, 5), Paint()..color = const Color(0xff75c4ce));
    canvas.drawRect(Rect.fromLTWH(c.x + 7, c.y - 10, 5, 5), Paint()..color = const Color(0xff75c4ce));
  }

  void _drawPeople(Canvas canvas) {
    for (var i = 0; i < 15; i++) {
      final c = _center(4 + (i * 11) % 19, 5 + (i * 7) % 14);
      final bob = math.sin(i * 2.1) * 1.5;
      canvas.drawCircle(Offset(c.x, c.y - 3 + bob), 2.6, Paint()..color = const Color(0xffffd085));
      canvas.drawLine(Offset(c.x, c.y, ), Offset(c.x, c.y + 4 + bob), Paint()..color = i.isEven ? const Color(0xffb54a38) : const Color(0xff31577b)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => _GlassPanel(
        child: Row(children: [
          const Icon(Icons.park, color: Color(0xffffcb56), size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text('ОДИН ДВОР  ·  ЦИВИЛИЗАЦИЯ', maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: compact ? 11 : 15))),
          if (!compact) const _Resource(icon: Icons.currency_ruble, value: '1 250'),
          const _Resource(icon: Icons.grass, value: '680'),
          const _Resource(icon: Icons.people_alt, value: '72'),
          const SizedBox(width: 4),
          const Icon(Icons.settings, size: 21, color: Colors.white70),
        ]),
      );
}

class _Resource extends StatelessWidget {
  const _Resource({required this.icon, required this.value});
  final IconData icon; final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Row(children: [Icon(icon, size: 17, color: const Color(0xffffd05c)), const SizedBox(width: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}

class _SidePanel extends StatelessWidget {
  const _SidePanel();
  @override
  Widget build(BuildContext context) => Column(children: const [
    _InfoCard(title: 'ПОСЕЛЕНИЕ', icon: Icons.people_alt, rows: ['Жители          72', 'Счастье          87%', 'Занятость        64%', 'Здоровье         92%']),
    SizedBox(height: 10),
    _InfoCard(title: 'ПРИРОДА', icon: Icons.forest, rows: ['Лес              72%', 'Чистота          92%', 'Плодородие       78%', 'Погода           Ясно']),
    Spacer(),
    _InfoCard(title: 'ГОД 1  ·  ВЕСНА', icon: Icons.event, rows: ['Первые дома ждут жителей', 'Дороги соединяют двор']),
  ]);
}

class _CompactStats extends StatelessWidget {
  const _CompactStats();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: _GlassPanel(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Text('🌱 Весна  ·  Год 1       👥 72       🌲 72%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.rows});
  final String title; final IconData icon; final List<String> rows;
  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: const Color(0xffffcd55), size: 18), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .5))]),
      const Divider(height: 16, color: Colors.white24),
      for (final row in rows) Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(row, style: const TextStyle(fontSize: 12))),
    ]),
  );
}

class _BuildBar extends StatelessWidget {
  const _BuildBar({required this.compact, required this.selected, required this.onSelect, required this.onBuild});
  final bool compact; final int selected; final ValueChanged<int> onSelect; final VoidCallback onBuild;
  static const items = [
    (Icons.home_work, 'Жильё'), (Icons.factory, 'Ферма'),
    (Icons.storefront, 'Рынок'), (Icons.add_road, 'Дорога'),
    (Icons.park, 'Парк'), (Icons.account_balance, 'Совет'),
  ];
  @override
  Widget build(BuildContext context) => _GlassPanel(padding: EdgeInsets.all(compact ? 6 : 10),
    child: Row(children: [
      if (!compact) const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('СТРОИТЕЛЬСТВО', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xffffd05c)))),
      for (var i = 0; i < items.length; i++) Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(color: selected == i ? const Color(0xff245a70) : const Color(0xff172c34), borderRadius: BorderRadius.circular(12),
          child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () { onSelect(i); onBuild(); },
            child: Padding(padding: EdgeInsets.symmetric(vertical: compact ? 9 : 11), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(items[i].$1, color: selected == i ? const Color(0xffffd05c) : Colors.white, size: compact ? 19 : 23),
              if (!compact) ...[const SizedBox(height: 3), Text(items[i].$2, style: const TextStyle(fontSize: 10))],
            ])),
          ),
        ),
      )),
      const SizedBox(width: 6),
      const Icon(Icons.pause_circle_filled, color: Color(0xffffd05c), size: 30),
    ]),
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(12)});
  final Widget child; final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xe9152428),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xff66848a), width: 1),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: child,
  );
}
