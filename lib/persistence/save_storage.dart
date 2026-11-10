import 'game_save.dart';

/// Minimal file operations required by [GameSaveRepository].
/// Keeping I/O behind this interface makes recovery behavior testable.
abstract interface class SaveFileStore {
  Future<bool> exists(String name);
  Future<String> read(String name);
  Future<void> write(String name, String contents);
  Future<void> rename(String from, String to);
  Future<void> delete(String name);
}

/// Saves the game in app-private storage using temp-write + rename.
/// A previous valid save is retained as `.bak` until the next successful save.
class GameSaveRepository {
  GameSaveRepository(this.store);

  final SaveFileStore store;

  static const String primaryName = 'one_yard_save.json';
  static const String temporaryName = 'one_yard_save.json.tmp';
  static const String backupName = 'one_yard_save.json.bak';

  Future<void> save(GameSave save) async {
    final encoded = save.encode();

    // Write and flush the complete new save before touching the current one.
    await store.write(temporaryName, encoded);

    final hadPrimary = await store.exists(primaryName);
    if (hadPrimary) {
      if (await store.exists(backupName)) {
        await store.delete(backupName);
      }
      await store.rename(primaryName, backupName);
    }

    try {
      await store.rename(temporaryName, primaryName);
    } catch (_) {
      // Restore the previous save if promotion of the temp file fails.
      if (hadPrimary &&
          !await store.exists(primaryName) &&
          await store.exists(backupName)) {
        await store.rename(backupName, primaryName);
      }
      rethrow;
    }
  }

  /// Reads primary first, then backup. A corrupt primary is never deleted
  /// automatically, so it remains available for manual diagnostics.
  Future<GameSave?> load() async {
    if (await store.exists(primaryName)) {
      try {
        return GameSave.decode(await store.read(primaryName));
      } on FormatException {
        // Fall through to the last known-good backup.
      } on UnsupportedError {
        // A newer/unsupported primary may still have an older valid backup.
      }
    }

    if (await store.exists(backupName)) {
      try {
        return GameSave.decode(await store.read(backupName));
      } on FormatException {
        return null;
      } on UnsupportedError {
        return null;
      }
    }
    return null;
  }
}
