import 'package:flutter_test/flutter_test.dart';

import 'package:starcade/core/model/chess_profile.dart';
import 'package:starcade/core/save/defaults.dart';
import 'package:starcade/core/services/save_controller.dart';

import 'memory_save_repository.dart';

void main() {
  test('ChessProfile json roundtrip preserves every field', () {
    const p = ChessProfile(
        themeId: 'wood',
        pieceSetId: 'letter',
        flipBoard: true,
        wins: 3,
        losses: 1,
        draws: 2,
        aiWins: 5,
        aiLosses: 4,
        aiDraws: 1);
    final back = ChessProfile.fromJson(p.toJson());
    expect(back.themeId, 'wood');
    expect(back.pieceSetId, 'letter');
    expect(back.flipBoard, isTrue);
    expect(back.wins, 3);
    expect(back.losses, 1);
    expect(back.draws, 2);
    expect(back.aiWins, 5);
    expect(back.aiLosses, 4);
    expect(back.aiDraws, 1);
  });

  test('defaults produce an empty, unearned profile', () {
    expect(newChessProfile().wins, 0);
    expect(newChessProfile().themeId, 'nebula');
  });

  test('save roundtrip through SaveController survives a reload', () async {
    final repo = MemorySaveRepository();
    final a = SaveController(repository: repo);
    await a.load();
    a.profile = a.profile.copyWith(wins: 7);
    await a.saveNow();
    final b = SaveController(repository: repo);
    final r = await b.load();
    expect(r.profile.wins, 7, reason: 'atomic save must persist ChessProfile');
  });
}
