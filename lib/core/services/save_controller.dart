/// Owns save/load for the whole app. One instance, built at boot, injected
/// everywhere. Load runs the corruption recovery ladder; saveNow is atomic and
/// flushes on meaningful events + app lifecycle.
library;

import 'dart:async';
import 'dart:convert';

import '../model/chess_profile.dart';
import '../save/checksum.dart';
import '../save/defaults.dart';
import '../save/envelope.dart';
import '../save/migration.dart';
import 'save_repository.dart';

/// Outcome of a load, so the UI can tell the player "your last known good
/// save was restored" vs. "fresh start".
enum LoadSource { loaded, recoveredFromBackup, seededDefaults }

class LoadResult {
  const LoadResult({required this.profile, required this.source});
  final ChessProfile profile;
  final LoadSource source;
}

class SaveController {
  SaveController({required this.repository});

  final ILocalSaveRepository repository;

  /// The in-memory chess profile. Mutate (copyWith) then persist via
  /// [saveNow]; [replaceProfile] does both.
  ChessProfile profile = newChessProfile();

  LoadSource _lastSource = LoadSource.seededDefaults;
  LoadSource get lastSource => _lastSource;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Atomic write guard: serializes mutations so two events can't interleave
  /// a transaction. Saves are synchronous under the hood on native, so this is
  /// cheap.
  bool _writing = false;

  /// Profile changes — the UI subscribes here (via Riverpod) so the launcher
  /// rebuilds when a match finishes or a setting lands. Each listener first
  /// receives the current profile, then live updates.
  final StreamController<ChessProfile> _changes =
      StreamController<ChessProfile>.broadcast();
  Stream<ChessProfile> get changes async* {
    yield profile;
    yield* _changes.stream;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(profile);
  }

  void dispose() {
    _changes.close();
  }

  Future<LoadResult> load() async {
    // Recovery ladder:
    // 1. Read canonical save; verify checksum.
    // 2. Corrupt/unreadable → preserve aside, try .bak.
    // 3. .bak good → restore; else seed defaults.
    // 4. Write a fresh backup immediately after a successful load.
    String? raw;
    try {
      raw = await repository.read();
    } on SaveCorruptException {
      raw = null;
    }

    if (raw != null) {
      final envelope = SaveEnvelope.tryDecode(raw);
      if (envelope != null &&
          checksumMatches(envelope.payload, envelope.checksum)) {
        try {
          final migrated =
              migratePayload(envelope.payload, fromVersion: envelope.schemaVersion);
          final loaded = ChessProfile.fromJson(migrated);
          profile = loaded;
          _loaded = true;
          _lastSource = LoadSource.loaded;
          await _writeBackup(loaded, DateTime.now());
          _notify();
          return LoadResult(profile: loaded, source: LoadSource.loaded);
        } on FormatException {
          // Payload failed to parse — treat as corrupt, fall through.
        } on StateError {
          // Newer schema — treat as corrupt rather than destroy.
        }
      }
      // Checksum failed or parse failed: preserve corrupt data for support.
      await repository.preserveCorrupt(raw);
    }

    // Try the backup.
    final backup = await repository.readBackup();
    if (backup != null) {
      final envelope = SaveEnvelope.tryDecode(backup);
      if (envelope != null &&
          checksumMatches(envelope.payload, envelope.checksum)) {
        try {
          final migrated =
              migratePayload(envelope.payload, fromVersion: envelope.schemaVersion);
          final recovered = ChessProfile.fromJson(migrated);
          profile = recovered;
          _loaded = true;
          _lastSource = LoadSource.recoveredFromBackup;
          // Restore the canonical save from the good backup.
          await _writeCanonical(recovered, DateTime.now());
          _notify();
          return LoadResult(profile: recovered, source: LoadSource.recoveredFromBackup);
        } on FormatException {
          // fall through to defaults
        } on StateError {
          // fall through to defaults
        }
      }
    }

    profile = newChessProfile();
    _loaded = true;
    _lastSource = LoadSource.seededDefaults;
    await _writeCanonical(profile, DateTime.now());
    await _writeBackup(profile, DateTime.now());
    _notify();
    return LoadResult(profile: profile, source: LoadSource.seededDefaults);
  }

  /// Persist the current profile immediately (atomic). Call on meaningful
  /// events, never per tick.
  Future<void> saveNow() async {
    if (!_loaded) return;
    // Serialize writers so concurrent events can't interleave.
    if (_writing) return;
    _writing = true;
    try {
      final savedAt = DateTime.now();
      await _writeCanonical(profile, savedAt);
      await _writeBackup(profile, savedAt);
    } finally {
      _writing = false;
    }
    _notify();
  }

  /// Replace the profile in memory + persist (used by settings "reset").
  Future<void> replaceProfile(ChessProfile value) async {
    profile = value;
    _loaded = true;
    await saveNow();
    _notify();
  }

  Future<void> _writeCanonical(ChessProfile value, DateTime savedAt) async {
    final payload = value.toJson();
    final envelope = SaveEnvelope.sign(payload, savedAt: savedAt);
    await repository.write(envelope.encode());
  }

  Future<void> _writeBackup(ChessProfile value, DateTime savedAt) async {
    final payload = value.toJson();
    final envelope = SaveEnvelope.sign(payload, savedAt: savedAt);
    await repository.writeBackup(envelope.encode());
  }

  // Convenience for tests/debug.
  String debugDump() => const JsonEncoder.withIndent('  ')
      .convert(profile.toJson());
}
