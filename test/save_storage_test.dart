import 'package:flutter_test/flutter_test.dart';
import 'package:one_yard_flutter/persistence/game_save.dart';
import 'package:one_yard_flutter/persistence/save_storage.dart';

class MemorySaveFileStore implements SaveFileStore {
  final Map<String, String> files = {};
  bool failTemporaryPromotion = false;

  @override
  Future<bool> exists(String name) async => files.containsKey(name);

  @override
  Future<String> read(String name) async => files[name]!;

  @override
  Future<void> write(String name, String contents) async {
    files[name] = contents;
  }

  @override
  Future<void> rename(String from, String to) async {
    if (failTemporaryPromotion && from == GameSaveRepository.temporaryName) {
      failTemporaryPromotion = false;
      throw StateError('Simulated rename failure');
    }
    final value = files.remove(from);
    if (value == null) throw StateError('Missing file: $from');
    files[to] = value;
  }

  @override
  Future<void> delete(String name) async {
    files.remove(name);
  }
}

void main() {
  group('GameSaveRepository', () {
    test('writes and reloads a save', () async {
      final store = MemorySaveFileStore();
      final repository = GameSaveRepository(store);
      final save = GameSave.create(payload: {'population': 12});

      await repository.save(save);
      final loaded = await repository.load();

      expect(loaded?.payload['population'], 12);
      expect(store.files.containsKey(GameSaveRepository.primaryName), isTrue);
    });

    test('keeps the previous save as backup after a new save', () async {
      final store = MemorySaveFileStore();
      final repository = GameSaveRepository(store);

      await repository.save(GameSave.create(payload: {'day': 1}));
      await repository.save(GameSave.create(payload: {'day': 2}));

      expect(store.files.containsKey(GameSaveRepository.backupName), isTrue);
      expect((await repository.load())?.payload['day'], 2);
      expect(
        GameSave.decode(store.files[GameSaveRepository.backupName]!).payload['day'],
        1,
      );
    });

    test('loads backup when primary save is corrupt', () async {
      final store = MemorySaveFileStore();
      final repository = GameSaveRepository(store);
      await repository.save(GameSave.create(payload: {'day': 7}));
      await repository.save(GameSave.create(payload: {'day': 8}));
      store.files[GameSaveRepository.primaryName] = '{broken json';

      final loaded = await repository.load();

      expect(loaded?.payload['day'], 7);
      expect(store.files[GameSaveRepository.primaryName], '{broken json');
    });

    test('restores old primary if promotion of temp file fails', () async {
      final store = MemorySaveFileStore();
      final repository = GameSaveRepository(store);
      await repository.save(GameSave.create(payload: {'day': 3}));
      store.failTemporaryPromotion = true;

      await expectLater(
        repository.save(GameSave.create(payload: {'day': 4})),
        throwsA(isA<StateError>()),
      );
      expect((await repository.load())?.payload['day'], 3);
    });
  });
}
