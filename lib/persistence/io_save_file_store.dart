import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'save_storage.dart';

/// Android/iOS app-private implementation. Files are not placed in public
/// Downloads, Music, or shared media folders.
class IoSaveFileStore implements SaveFileStore {
  IoSaveFileStore._(this._directory);

  final Directory _directory;

  static Future<IoSaveFileStore> create() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return IoSaveFileStore._(directory);
  }

  File _file(String name) {
    if (name.contains('/') || name.contains('\\') || name == '.' || name == '..') {
      throw ArgumentError.value(name, 'name', 'A plain file name is required');
    }
    return File('${_directory.path}${Platform.pathSeparator}$name');
  }

  @override
  Future<bool> exists(String name) => _file(name).exists();

  @override
  Future<String> read(String name) => _file(name).readAsString();

  @override
  Future<void> write(String name, String contents) async {
    await _file(name).writeAsString(contents, flush: true);
  }

  @override
  Future<void> rename(String from, String to) async {
    await _file(from).rename(_file(to).path);
  }

  @override
  Future<void> delete(String name) async {
    final file = _file(name);
    if (await file.exists()) await file.delete();
  }
}
