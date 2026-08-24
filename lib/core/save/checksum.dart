/// SHA-256 checksum over the payload (D4). Pure Dart via package:crypto, so it
/// works on every platform including web.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hex sha256 of the canonical JSON encoding of [payload].
///
/// The payload is encoded with a stable map order so checksums are
/// reproducible across writes: Dart's [JsonEncoder] uses [Map] insertion
/// order, and our models build maps in a fixed order, so two identical saves
/// produce identical checksums.
String checksumOf(Map<String, Object?> payload) {
  final bytes = utf8.encode(jsonEncode(payload));
  return sha256.convert(bytes).toString();
}

/// Constant-time-ish comparison is unnecessary here (integrity check, not
/// auth), but this reads clearer than `!=` and avoids accidental substring
/// mistakes.
bool checksumMatches(Map<String, Object?> payload, String expected) =>
    checksumOf(payload) == expected;
