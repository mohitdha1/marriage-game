import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/hand_arrangement.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

void main() {
  group('handHelperText', () {
    test('before the joker: pure sets and dublees toward the show', () {
      expect(
        handHelperText(
          const ShowProgress(pureSets: 2, pureSetsNeeded: 3, doublees: 5),
        ),
        'Sets 2/3 · Dublees 5/7',
      );
    });

    test('enough pure sets: ready to show', () {
      expect(
        handHelperText(
          const ShowProgress(pureSets: 4, pureSetsNeeded: 3, doublees: 1),
        ),
        'Ready to show · Dublees 1/7',
      );
      expect(
        handHelperText(
          const ShowProgress(pureSets: 0, pureSetsNeeded: 0, doublees: 0),
        ),
        'Ready to show · Dublees 0/7',
      );
    });

    test('dublees never read more than 7/7', () {
      expect(
        handHelperText(
          const ShowProgress(pureSets: 0, pureSetsNeeded: 3, doublees: 9),
        ),
        'Sets 0/3 · Dublees 7/7',
      );
    });

    test('after the joker: sets made and unmatched cards', () {
      expect(
        handHelperText(const WinProgress(setsMade: 5, unmatched: 4, maal: 7)),
        '5 sets · 4 unmatched',
      );
    });

    test('on the dublee route: progress to the 8th', () {
      expect(
        handHelperText(const DubleeProgress(doublees: 7, maal: 0)),
        'Dublees 7/8',
      );
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
        maalOf(const WinProgress(setsMade: 3, unmatched: 9, maal: 12)),
        12,
      );
      expect(maalOf(const DubleeProgress(doublees: 7, maal: 5)), 5);
    });
  });
}
