import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcade/ui/chess/themes/board_theme.dart';

void main() {
  test('Nebula is the default theme and defines the palette', () {
    expect(kBoardThemes.first.id, 'nebula');
    final neb = kBoardThemes.first;
    expect(neb.lightSquare, const Color(0xFF2E2454));
    expect(neb.darkSquare, const Color(0xFF191238));
  });

  test('wood and blue are present with their documented colors', () {
    final wood = kBoardThemes.firstWhere((t) => t.id == 'wood');
    expect(wood.lightSquare, const Color(0xFFF0D9B6));
    expect(wood.darkSquare, const Color(0xFFB58863));
    final blue = kBoardThemes.firstWhere((t) => t.id == 'blue');
    expect(blue.lightSquare, const Color(0xFFDEE3E6));
    expect(blue.darkSquare, const Color(0xFF8CA2AD));
  });

  test('every theme maps to a chessground color scheme', () {
    for (final t in kBoardThemes) {
      expect(t.colorScheme, isNotNull, reason: t.id);
    }
  });
}
