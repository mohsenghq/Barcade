/// Save envelope (D3): one JSON document wrapping the payload with a schema
/// version, write time, and checksum. The payload is the entire player save.
library;

import 'dart:convert';

import 'checksum.dart';

class SaveEnvelope {
  const SaveEnvelope({
    required this.schemaVersion,
    required this.savedAt,
    required this.checksum,
    required this.payload,
  });

  final int schemaVersion;
  final DateTime savedAt;
  final String checksum;
  final Map<String, Object?> payload;

  /// Current save schema version. Bump on any breaking payload change and add
  /// a migration step in [migration.dart]. Only one number to keep — the table
  /// is the source of truth.
  static const int currentVersion = 2;

  /// Build a current-version envelope over [payload], computing the checksum.
  /// The single construction path (save_controller + tests). [savedAt] is
  /// overridable so callers can pin a canonical write time.
  factory SaveEnvelope.sign(Map<String, Object?> payload, {DateTime? savedAt}) {
    return SaveEnvelope(
      schemaVersion: currentVersion,
      savedAt: savedAt ?? DateTime.now(),
      checksum: checksumOf(payload),
      payload: payload,
    );
  }

  String encode() => jsonEncode({
        'schemaVersion': schemaVersion,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'checksum': checksum,
        'payload': payload,
      });

  static SaveEnvelope? tryDecode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, Object?>) return null;
      final version = map['schemaVersion'];
      final savedAt = map['savedAt'];
      final checksum = map['checksum'];
      final payload = map['payload'];
      if (version is! int || savedAt is! String || checksum is! String) {
        return null;
      }
      if (payload is! Map<String, Object?>) return null;
      final parsed = DateTime.tryParse(savedAt);
      if (parsed == null) return null;
      return SaveEnvelope(
        schemaVersion: version,
        savedAt: parsed,
        checksum: checksum,
        payload: payload,
      );
    } on FormatException {
      return null;
    }
  }
}
