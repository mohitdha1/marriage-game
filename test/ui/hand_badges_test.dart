import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/hand_arrangement.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

void main() {
  group('toWinOf', () {
    test('nothing before the joker is seen', () {
      expect(
        toWinOf(
          const ShowProgress(pureSets: 3, pureSetsNeeded: 3, doublees: 7),
        ),
        isNull,
      );
      expect(toWinOf(null), isNull);
    });

    test('on the sets route: the sets still needed', () {
      expect(
        toWinOf(
          const WinProgress(setsMade: 4, unmatched: 7, setsToWin: 3, maal: 0),
        ),
        3,
      );
    });

    test('on the dublee route: 1 until the 8th doublee, then 0', () {
      expect(toWinOf(const DubleeProgress(doublees: 7, maal: 0)), 1);
      expect(toWinOf(const DubleeProgress(doublees: 8, maal: 0)), 0);
    });
  });

  group('toWinText', () {
    test('counts down, then says the hand is ready', () {
      expect(toWinText(3), '3 to win');
      expect(toWinText(1), '1 to win');
      expect(toWinText(0), 'Ready to win!');
    });
  });

  group('maalOf', () {
    test('only after seeing the joker', () {
      expect(
        maalOf(const ShowProgress(pureSets: 1, pureSetsNeeded: 3, doublees: 0)),
        isNull,
      );
      expect(maalOf(null), isNull);
      expect(
        maalOf(
          const WinProgress(setsMade: 3, unmatched: 9, setsToWin: 3, maal: 12),
        ),
        12,
      );
      expect(maalOf(const DubleeProgress(doublees: 7, maal: 5)), 5);
    });
  });
}
