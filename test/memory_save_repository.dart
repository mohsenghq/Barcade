/// Shared in-memory [ILocalSaveRepository] for save-layer tests. Mirrors the
/// helper that lived in the deleted test/support/test_services.dart (which
/// also dragged in the doomed arcade services).
library;

import 'package:starcade/core/services/save_repository.dart';

class MemorySaveRepository implements ILocalSaveRepository {
  String? _canonical;
  String? _backup;

  @override
  Future<String> read() async {
    final c = _canonical;
    if (c == null) throw const SaveCorruptException('no save yet');
    return c;
  }

  @override
  Future<bool> exists() async => _canonical != null;

  @override
  Future<void> write(String data) async => _canonical = data;

  @override
  Future<void> writeBackup(String data) async => _backup = data;

  @override
  Future<String?> readBackup() async => _backup;

  @override
  Future<void> preserveCorrupt(String corruptData) async {}

  @override
  Future<void> clear() async {
    _canonical = null;
    _backup = null;
  }
}
