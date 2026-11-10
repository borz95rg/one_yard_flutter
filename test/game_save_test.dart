import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/persistence/game_save.dart';

void main() {
  group('GameSave', () {
    test('round-trips a versioned Flutter save', () {
      final original = GameSave.create(
        now: DateTime.utc(2026, 11, 10),
        payload: {
          'world': {'year': 12, 'seasonIndex': 2},
          'residents': [
            {'id': 'r1', 'familyId': 'f1'}
          ],
        },
      );

      final restored = GameSave.decode(original.encode());
      expect(restored.schemaVersion, GameSave.currentSchemaVersion);
      expect(restored.savedAtUtc, DateTime.utc(2026, 11, 10));
      expect(restored.payload, original.payload);
      expect(restored.legacyHtmlSave, isNull);
    });

    test('preserves the complete legacy HTML v18 object', () {
      final legacy = <String, dynamic>{
        'version': 18,
        'worldYear': 7,
        'objects': [
          {'type': 'house', 'x': 12, 'y': 34}
        ],
        'residents': [
          {'id': 41, 'friendIds': [42], 'childIds': [43]}
        ],
        'unknownFutureField': {'keep': true},
      };

      final restored = GameSave.decode(jsonEncode(legacy));
      expect(restored.legacyHtmlSave, legacy);
      expect(restored.payload['migration']['sourceVersion'], 18);
      expect(restored.payload['migration']['status'],
          'raw_preserved_field_mapping_pending');
    });

    test('rejects malformed and unsupported saves', () {
      expect(() => GameSave.decode('[]'), throwsFormatException);
      expect(() => GameSave.decode('{"version":"18"}'),
          throwsFormatException);
      expect(
        () => GameSave.decode(
            '{"format":"${GameSave.format}","schemaVersion":99,"payload":{},"savedAtUtc":"2026-01-01"}'),
        throwsFormatException,
      );
    });
  });
}
