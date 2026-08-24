/// Payload migrations. v1 was the arcade profile; v2 is the chess profile.
/// Every future version bump adds one step, never a rewrite.
library;

import 'envelope.dart';

/// Migrate a raw payload map from [fromVersion] to [currentVersion],
/// returning the payload at [currentVersion]. Unknown future versions are
/// rejected (never silently downgrade).
Map<String, Object?> migratePayload(
  Map<String, Object?> payload, {
  required int fromVersion,
}) {
  final current = _currentVersion;
  if (fromVersion > current) {
    throw StateError('save is from a newer schema ($fromVersion > $current)');
  }
  var out = payload;
  // v1 is the first released schema; anything older (v0 pre-release) is
  // treated as v1 so the pass-through assert below always holds.
  var v = fromVersion < 1 ? 1 : fromVersion;
  // v1 (arcade profile) → v2 (chess profile): the old profile is meaningless
  // after the pivot; reset to an empty payload so fromJson fills defaults.
  if (v < 2) out = _resetToDefaults(out);
  v = 2;
  assert(v == current);
  return out;
}

Map<String, Object?> _resetToDefaults(Map<String, Object?> _) => {};

/// The schema version's single source of truth is the envelope. Migration
/// must never carry its own literal — a divergence would make every load throw
/// StateError and the recovery ladder wipe the player's save on each launch.
int get _currentVersion => SaveEnvelope.currentVersion;
