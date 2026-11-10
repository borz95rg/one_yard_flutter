import '../game/world_state.dart';
import 'dart:convert';

/// Versioned, JSON-based local save container for the Flutter migration.
///
/// `payload` is deliberately data-only. Game systems can be migrated into it
/// incrementally without coupling persistence to Flame or UI classes.
class GameSave {
  const GameSave({
    required this.schemaVersion,
    required this.savedAtUtc,
    required this.payload,
    this.legacyHtmlSave,
  });

  static const int currentSchemaVersion = 1;
  static const String format = 'one_yard_flutter_save';

  final int schemaVersion;
  final DateTime savedAtUtc;
  final Map<String, dynamic> payload;

  /// Original HTML save, retained losslessly until each field has a verified
  /// Dart equivalent. This avoids silently discarding unsupported v18 fields.
  final Map<String, dynamic>? legacyHtmlSave;

  String encode() {
    if (schemaVersion != currentSchemaVersion) {
      throw UnsupportedError('Cannot write save schema $schemaVersion');
    }
    return jsonEncode(<String, dynamic>{
      'format': format,
      'schemaVersion': schemaVersion,
      'savedAtUtc': savedAtUtc.toUtc().toIso8601String(),
      'payload': payload,
      if (legacyHtmlSave != null) 'legacyHtmlSave': legacyHtmlSave,
    });
  }

  factory GameSave.create({
    required Map<String, dynamic> payload,
    DateTime? now,
  }) =>
      GameSave(
        schemaVersion: currentSchemaVersion,
        savedAtUtc: (now ?? DateTime.now()).toUtc(),
        payload: payload,
      );

  /// Reads the Flutter envelope, or wraps a legacy HTML localStorage object.
  /// The HTML source currently writes `version: 18` despite its v19 filename.
  factory GameSave.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Save root must be a JSON object');
    }
    final root = Map<String, dynamic>.from(decoded);

    if (root['format'] == format) {
      final version = root['schemaVersion'];
      if (version is! int || version < 1 || version > currentSchemaVersion) {
        throw FormatException('Unsupported save schema: $version');
      }
      final payload = root['payload'];
      final timestamp = DateTime.tryParse('${root['savedAtUtc']}');
      if (payload is! Map || timestamp == null) {
        throw const FormatException('Save envelope is incomplete');
      }
      final legacy = root['legacyHtmlSave'];
      return GameSave(
        schemaVersion: version,
        savedAtUtc: timestamp.toUtc(),
        payload: Map<String, dynamic>.from(payload),
        legacyHtmlSave:
            legacy is Map ? Map<String, dynamic>.from(legacy) : null,
      );
    }

    // Legacy HTML format: preserve the entire original object unchanged.
    final legacyVersion = root['version'];
    if (legacyVersion is! int) {
      throw const FormatException('Unknown save format');
    }
    return GameSave(
      schemaVersion: currentSchemaVersion,
      savedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      payload: <String, dynamic>{
        'migration': <String, dynamic>{
          'source': 'html_localStorage_one_yard_save',
          'sourceVersion': legacyVersion,
          'sourceFilenameVersion': 19,
          'status': 'partial_world_state_mapped_other_fields_pending',
        },
        'worldState': WorldState.fromLegacyHtml(root).toJson(),
      },
      legacyHtmlSave: root,
    );
  }
}
