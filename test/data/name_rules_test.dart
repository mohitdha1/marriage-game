import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/name_rules.dart';

/// The app's own rules, with its own list of blocked words.
final rules = NameRules.fromList(File(NameRules.asset).readAsStringSync());

void main() {
  group('Length and characters', () {
    test('2 to 16 characters, counted after trimming', () {
      expect(rules.problemWith('A'), 'Use at least 2 characters.');
      expect(rules.problemWith('  A  '), 'Use at least 2 characters.');
      expect(rules.problemWith('Al'), isNull);
      expect(rules.problemWith('Abcdefghijklmnop'), isNull);
      expect(
        rules.problemWith('Abcdefghijklmnopq'),
        'Use at most 16 characters.',
      );
    });

    test('letters in any script, numbers, spaces and . _ - \' are allowed', () {
      for (final name in [
        'Mohit',
        'Ram Bahadur',
        'मोहित',
        'राम बहादुर',
        'Asha_99',
        'J.K. Rai',
        "D'Souza",
        'Anne-Marie',
      ]) {
        expect(rules.problemWith(name), isNull, reason: name);
      }
    });

    test('other symbols, emoji and names with no letter are refused', () {
      expect(
        rules.problemWith('Mohit!'),
        'Use letters, numbers, spaces and . _ - only.',
      );
      expect(rules.problemWith('Ace 😀'), isNotNull);
      expect(rules.problemWith('<b>Hi</b>'), isNotNull);
      expect(rules.problemWith('12345'), 'Include at least one letter.');
      expect(rules.problemWith('-- --'), 'Include at least one letter.');
    });

    test('a name is kept trimmed, with runs of spaces made one', () {
      expect(NameRules.tidy('  Ram    Bahadur '), 'Ram Bahadur');
    });
  });

  group('Blocked words', () {
    const refused = 'Please choose a different name.';

    test('are refused in any case, and inside other words when marked', () {
      expect(rules.problemWith('fuck'), refused);
      expect(rules.problemWith('FuckBoy'), refused);
      expect(rules.problemWith('xxbitchxx'), refused);
      expect(rules.problemWith('Muji'), refused);
      expect(rules.problemWith('machikne raja'), refused);
    });

    test('look-alikes and broken-up spellings are caught', () {
      for (final name in [
        'a55',
        'A S S',
        'a.s.s',
        'sh1t',
        'b1tch',
        'f u c k',
      ]) {
        expect(rules.problemWith(name), refused, reason: name);
      }
    });

    test('short words are caught only on their own, so real names pass', () {
      for (final name in [
        'Ashita',
        'Cassandra',
        'Dickens',
        'Brandi',
        'Mujibur',
        'Sushil',
        'Hancock',
        'Scunthorpe',
      ]) {
        expect(rules.problemWith(name), isNull, reason: name);
      }
      expect(rules.problemWith('big ass'), refused);
      expect(rules.problemWith('Randi'), refused);
    });

    test('the list reads one word a line, skipping blanks and comments', () {
      final custom = NameRules.fromList('# words\n\n*zork\nbad\n  \n');

      expect(custom.problemWith('Mazorkle'), refused);
      expect(custom.problemWith('Bad'), refused);
      expect(custom.problemWith('Badal'), isNull);
      expect(custom.problemWith('words'), isNull);
    });
  });
}
