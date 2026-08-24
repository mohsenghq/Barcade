import 'dart:convert';
import 'dart:io';

/// Model contract (docs/CHESS_AI_CONTRACT.md, mirrored from the trainer).
///
/// The manifest is the source of truth for the artifact's format; the app
/// refuses to run the model on mismatch. Versioning lives in manifest.json,
/// never in ONNX metadata.

class ModelContract {
  ModelContract._();

  static const expectedNetworkFormatVersion = 'az119/v1';
  static const inputShape = [1, 119, 8, 8];
  static const policyShape = [1, 8, 8, 73];
  static const valueShape = [1, 1];

  /// Asset key of the on-device artifact (int8 quantized, from the trainer's
  /// export step). Gitignored; `dart run tool/fetch_net.dart` fetches it.
  static const assetKey = 'assets/ai/chess_net.onnx';
  static const manifestAssetKey = 'assets/ai/manifest.json';

  /// True when the model asset is present at the given file path.
  static bool isAvailable({String? assetsDir}) {
    final base = assetsDir ?? 'assets/ai';
    return File('$base/chess_net.onnx').existsSync() &&
        File('$base/manifest.json').existsSync();
  }

  /// Loads the manifest and verifies the network format version. Returns the
  /// error message when the artifact is unusable, null when it is good.
  static String? verifyManifest({String? assetsDir}) {
    final base = assetsDir ?? 'assets/ai';
    final file = File('$base/manifest.json');
    if (!file.existsSync()) return 'manifest.json missing';
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final format = json['network_format_version'] as String?;
    if (format != expectedNetworkFormatVersion) {
      return 'model format $format != $expectedNetworkFormatVersion';
    }
    final policy = (json['policy_shape'] as List?)?.cast<int>();
    // Dart List.== is identity, so compare element-wise.
    if (policy == null || policy.length != policyShape.length) {
      return 'policy_shape mismatch: $policy';
    }
    for (var i = 0; i < policyShape.length; i++) {
      if (policy[i] != policyShape[i]) return 'policy_shape mismatch: $policy';
    }
    return null;
  }
}
