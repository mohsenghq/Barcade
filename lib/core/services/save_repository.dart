/// The storage seam for the save envelope (D12). One interface, two
/// backends: a file in the app documents dir on native platforms, and
/// localStorage via shared_preferences on web (no dart:io there).
///
/// The interface is deliberately storage-shaped, not envelope-shaped: the
/// [SaveController] owns envelope logic, checksums, and the recovery ladder;
/// the repository just persists an opaque string reliably.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown by [ILocalSaveRepository.read] when the stored data cannot be read
/// (missing, corrupt JSON, IO error). The controller treats this as "try the
/// backup" — it is not an app crash.
class SaveCorruptException implements Exception {
  const SaveCorruptException(this.message);
  final String message;
  @override
  String toString() => 'SaveCorruptException: $message';
}

abstract interface class ILocalSaveRepository {
  /// Read the raw stored save string. Throws [SaveCorruptException] on any
  /// read failure or when no save exists (callers may distinguish "no save
  /// yet" via [exists]).
  Future<String> read();

  Future<bool> exists();

  /// Write [data] as the canonical save.
  Future<void> write(String data);

  /// Write [data] as the "last known good" backup.
  Future<void> writeBackup(String data);

  /// Try to read the backup. Returns null if there is no usable backup.
  Future<String?> readBackup();

  /// Rename a corrupt save aside (never delete) so support/cloud recovery can
  /// find it later (D4).
  Future<void> preserveCorrupt(String corruptData);

  /// Delete all stored save data (used by "reset progress" in settings).
  Future<void> clear();
}

/// Native implementation: one JSON file + one .bak file in the app documents
/// directory, written atomically via temp-then-rename (D4).
class FileSaveRepository implements ILocalSaveRepository {
  // A private named parameter would leak the field name into the public
  // constructor; keep it public and optional.
  // ignore: prefer_initializing_formals
  FileSaveRepository({Directory? directory}) : _directory = directory;

  final Directory? _directory;
  Directory? _resolved;

  static const _saveName = 'save.json';
  static const _backupName = 'save.bak.json';
  static const _corruptPrefix = 'save.corrupt.';

  Future<Directory> _dir() async {
    if (_resolved != null) return _resolved!;
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    _resolved = dir;
    return dir;
  }

  Future<File> _saveFile() async => File('${(await _dir()).path}/$_saveName');

  Future<File> _backupFile() async =>
      File('${(await _dir()).path}/$_backupName');

  @override
  Future<bool> exists() async => (await _saveFile()).existsSync();

  @override
  Future<String> read() async {
    final f = await _saveFile();
    if (!f.existsSync()) throw const SaveCorruptException('no save file');
    try {
      return f.readAsStringSync();
    } on IOException catch (e) {
      throw SaveCorruptException('read failed: $e');
    }
  }

  @override
  Future<void> write(String data) async {
    final f = await _saveFile();
    // Atomic on POSIX and NTFS: write temp, flush, rename over the real file.
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(data, flush: true);
    tmp.renameSync(f.path);
  }

  @override
  Future<void> writeBackup(String data) async {
    final f = await _backupFile();
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(data, flush: true);
    tmp.renameSync(f.path);
  }

  @override
  Future<String?> readBackup() async {
    final f = await _backupFile();
    if (!f.existsSync()) return null;
    try {
      return f.readAsStringSync();
    } on IOException {
      return null;
    }
  }

  @override
  Future<void> preserveCorrupt(String corruptData) async {
    final dir = await _dir();
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final f = File('${dir.path}/$_corruptPrefix$ts.json');
    try {
      f.writeAsStringSync(corruptData, flush: true);
    } on IOException {
      // Best-effort: if we can't preserve, at least don't crash the ladder.
    }
  }

  @override
  Future<void> clear() async {
    final f = await _saveFile();
    final b = await _backupFile();
    if (f.existsSync()) f.deleteSync();
    if (b.existsSync()) b.deleteSync();
  }
}

/// Web implementation: localStorage via shared_preferences. No rename atomicity
/// exists, so the canonical save is stored under one key and the previous good
/// copy under a backup key; on load, if the canonical key is unreadable we fall
/// back to the backup key (the controller's ladder handles the rest).
class WebSaveRepository implements ILocalSaveRepository {
  static const _key = 'arcade_vault.save';
  static const _backupKey = 'arcade_vault.save.bak';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<bool> exists() async => (await _prefs()).containsKey(_key);

  @override
  Future<String> read() async {
    final prefs = await _prefs();
    final s = prefs.getString(_key);
    if (s == null) throw const SaveCorruptException('no save in prefs');
    return s;
  }

  @override
  Future<void> write(String data) async {
    final prefs = await _prefs();
    // Keep the previous good value as backup before overwriting.
    final prev = prefs.getString(_key);
    if (prev != null) await prefs.setString(_backupKey, prev);
    await prefs.setString(_key, data);
  }

  @override
  Future<void> writeBackup(String data) async {
    await (await _prefs()).setString(_backupKey, data);
  }

  @override
  Future<String?> readBackup() async {
    final prefs = await _prefs();
    return prefs.getString(_backupKey);
  }

  @override
  Future<void> preserveCorrupt(String corruptData) async {
    // localStorage has no rename; keep a diagnostic copy under a timestamp key.
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (await _prefs())
        .setString('arcade_vault.save.corrupt.$ts', corruptData);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_key);
    await prefs.remove(_backupKey);
  }
}

/// Build the right repository for the current platform.
Future<ILocalSaveRepository> createSaveRepository() async {
  if (kIsWeb) return WebSaveRepository();
  return FileSaveRepository();
}
