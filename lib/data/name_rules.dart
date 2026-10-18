/// What makes a display name acceptable: 2 to 16 characters of letters
/// (any script, Devanagari included), numbers, spaces and `. _ - '`, with
/// at least one letter, and none of the [blocked] words.
///
/// Each blocked word is matched after folding look-alikes ("@" for "a",
/// "0" for "o" and so on) and ignoring spaces and punctuation between
/// letters, so "a.s.s" and "a55" read as "ass". A word written with a
/// leading `*` in the list is caught anywhere in a name; any other only as
/// a whole word, or as the whole name, so ordinary names that happen to
/// contain it are left alone.
class NameRules {
  NameRules(Iterable<String> blocked)
    : _anywhere = {
        for (final word in blocked)
          if (word.startsWith('*')) _fold(word.substring(1)),
      }..remove(''),
      _whole = {
        for (final word in blocked)
          if (!word.startsWith('*')) _fold(word),
      }..remove('');

  /// Reads the rules' blocked words from [list]: one a line, with blank
  /// lines and lines starting `#` left out.
  factory NameRules.fromList(String list) => NameRules([
    for (final line in list.split('\n'))
      if (line.trim() case final word
          when word.isNotEmpty && !word.startsWith('#'))
        word,
  ]);

  /// The list of blocked words, as listed in pubspec.yaml.
  static const asset = 'assets/config/blocked_words.txt';

  static const minLength = 2;
  static const maxLength = 16;

  final Set<String> _anywhere;
  final Set<String> _whole;

  static final _allowed = RegExp(r"^[\p{L}\p{M}\p{N} ._\-']+$", unicode: true);
  static final _letter = RegExp(r'\p{L}', unicode: true);

  /// [name] as it's kept: trimmed, with runs of spaces made one.
  static String tidy(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// What's wrong with [name], as a short message for the player, or
  /// `null` if it's fine. The name is [tidy]ed first.
  String? problemWith(String name) {
    final tidied = tidy(name);
    final length = tidied.runes.length;
    if (length < minLength) return 'Use at least $minLength characters.';
    if (length > maxLength) return 'Use at most $maxLength characters.';
    if (!_allowed.hasMatch(tidied)) {
      return 'Use letters, numbers, spaces and . _ - only.';
    }
    if (!_letter.hasMatch(tidied)) return 'Include at least one letter.';
    if (_isBlocked(tidied)) return 'Please choose a different name.';
    return null;
  }

  bool _isBlocked(String name) {
    final folded = _fold(name);
    if (_anywhere.any(folded.contains) || _whole.contains(folded)) return true;
    final words = _foldWords(name);
    return words.any(_whole.contains);
  }

  static const _lookAlikes = {
    '0': 'o',
    '1': 'i',
    '!': 'i',
    '|': 'i',
    '3': 'e',
    '4': 'a',
    '@': 'a',
    '5': 's',
    r'$': 's',
    '7': 't',
    '8': 'b',
    '9': 'g',
  };

  static String _foldChar(String c) => _lookAlikes[c] ?? c.toLowerCase();

  /// [text] in lower case with look-alikes replaced and everything but the
  /// letters a to z dropped.
  static String _fold(String text) => text
      .split('')
      .map(_foldChar)
      .where((c) => c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7a)
      .join();

  /// The words of [text], each [_fold]ed, split at spaces only, so a word
  /// spelt out with dots ("a.s.s") stays one word.
  static Iterable<String> _foldWords(String text) =>
      text.split(' ').map(_fold).where((w) => w.isNotEmpty);
}
