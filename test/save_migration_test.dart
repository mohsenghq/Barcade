/// Migration ladder tests: v1 (arcade) payloads are reset by design — the
/// pivot made the old profile meaningless — and newer schemas are never
/// silently downgraded.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:starcade/core/save/migration.dart';

void main() {
  test('v1 arcade payload resets to an empty map so fromJson fills defaults',
      () {
    final out = migratePayload(
      {'arcade': 'garbage', 'anyKey': 1},
      fromVersion: 1,
    );
    expect(out, isEmpty,
        reason: 'the v1 arcade profile is meaningless after the chess pivot');
  });

  test('a payload from a newer schema throws StateError (never downgrade)', () {
    expect(
      () => migratePayload({}, fromVersion: 3),
      throwsStateError,
      reason: 'current schema is 2; a 3.x save must not be silently rewritten',
    );
  });
}
