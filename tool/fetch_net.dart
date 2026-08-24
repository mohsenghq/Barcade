// Fetches the trained model artifact from the pinned GitHub Release into
// the gitignored assets/ai/, verifying sha256 + manifest format.
//
//   dart run tool/fetch_net.dart
//
// The artifact is the output of RL_game_train (`python -m src.cli export`),
// shipped as a `net-v*` GitHub Release. Re-run after every net update.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The pinned release. Bump alongside the trainer's net-v* tag.
const netVersion = 'net-v0.1';
const baseUrl =
    'https://github.com/mohsenghq/Arcade-vault/releases/download/$netVersion';

Future<void> main() async {
  final dir = Directory('assets/ai')..createSync(recursive: true);
  final manifestBytes = await _download('$baseUrl/manifest.json');
  final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map;
  final modelSha = manifest['model_sha256'] as String;
  final format = manifest['network_format_version'] as String?;
  if (format != 'az119/v1') {
    throw StateError('unexpected network format: $format');
  }
  File('${dir.path}/manifest.json').writeAsBytesSync(manifestBytes);

  final onnxBytes = await _download('$baseUrl/chess_net_int8.onnx');
  final sha = sha256.convert(onnxBytes).toString();
  if (sha != modelSha) {
    throw StateError('sha256 mismatch: got $sha, manifest says $modelSha');
  }
  File('${dir.path}/chess_net.onnx').writeAsBytesSync(onnxBytes);
  stdout.writeln(
      'fetched chess_net.onnx (${onnxBytes.length ~/ 1024} KiB), sha256=$sha');
}

Future<List<int>> _download(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'starcade-fetch');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('GET $url -> ${response.statusCode}');
    }
    return await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
  } finally {
    client.close();
  }
}
