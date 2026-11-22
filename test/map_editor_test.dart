import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/game/isometric_grid.dart';
import 'package:one_yard_flutter/main.dart';
import 'package:one_yard_flutter/persistence/game_save.dart';

void main() {
  test('river, elevation and district edits survive save restoration', () {
    final map = SettlementMap();
    expect(map.paintTerrain(const GridCell(0, 0), 5), isTrue);
    expect(map.paintTerrain(const GridCell(1, 0), 7), isTrue);
    expect(map.paintTerrain(const GridCell(2, 0), 11), isTrue);

    final save = GameSave.create(payload: map.toJson());
    final restored = SettlementMap()..restore(save);
    final payload = restored.toJson();

    expect(payload['riverCells'], [0]);
    expect(payload['elevations'], {'1': 2});
    expect(payload['districts'], {'2': 2});
  });
}
