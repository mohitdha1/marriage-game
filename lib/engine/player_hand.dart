import 'card.dart';
import 'joker.dart';
import 'melds.dart';

/// How a player earned the right to see the joker.
enum ShowKind {
  /// Showed 3 pure sets (each a pure sequence or a tunnella).
  pureSets,

  /// Showed 7 doublees, and plays the dublee game from then on.
  doublees,
}

/// One player's cards and their side of a turn: draw, optionally show, then
/// discard. Which player's turn it is, and where the drawn card comes from,
/// are decided by the round, not here.
///
/// Until a player shows, they haven't "seen" the joker: they can't use wild
/// cards, and [visibleJokers] hides the round's jokers from them.
class PlayerHand {
  PlayerHand(Iterable<PlayingCard> cards) : _cards = [...cards];

  static const pureSetsToShow = 3;
  static const doubleesToShow = 7;

  final List<PlayingCard> _cards;
  final List<List<PlayingCard>> _shownSets = [];
  bool _hasDrawn = false;
  ShowKind? _showKind;

  /// Cards still held, not counting any that have been shown.
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  /// Sets laid face-up when the player showed; empty until then.
  List<List<PlayingCard>> get shownSets =>
      List.unmodifiable(_shownSets.map(List<PlayingCard>.unmodifiable));

  /// Whether the player has drawn this turn and still owes a discard.
  bool get hasDrawn => _hasDrawn;

  /// How the player showed, or `null` if they haven't yet.
  ShowKind? get showKind => _showKind;

  bool get hasSeenJoker => _showKind != null;

  /// The round's [jokers] if this player has seen them, otherwise `null`.
  Jokers? visibleJokers(Jokers jokers) => hasSeenJoker ? jokers : null;

  /// Starts the player's turn by adding [card] to their hand.
  void draw(PlayingCard card) {
    if (_hasDrawn) {
      throw StateError('Already drew this turn; discard first');
    }
    _cards.add(card);
    _hasDrawn = true;
  }

  /// Ends the player's turn by removing one copy of [card] from their hand.
  void discard(PlayingCard card) {
    if (!_hasDrawn) {
      throw StateError('Must draw before discarding');
    }
    if (!_cards.remove(card)) {
      throw ArgumentError.value(card, 'card', 'is not in the hand');
    }
    _hasDrawn = false;
  }

  /// Shows exactly 3 pure sets — each a pure sequence (3 to 5 cards) or a
  /// tunnella — to see the joker.
  void showPureSets(List<List<PlayingCard>> sets) {
    _show(
      sets,
      kind: ShowKind.pureSets,
      requiredCount: pureSetsToShow,
      isValidSet: (set) => isPureSequence(set) || isTunnella(set),
    );
  }

  /// Shows exactly 7 doublees to see the joker.
  void showDoublees(List<List<PlayingCard>> pairs) {
    _show(
      pairs,
      kind: ShowKind.doublees,
      requiredCount: doubleesToShow,
      isValidSet: isDoublee,
    );
  }

  /// Checks everything before changing anything, so a rejected show leaves
  /// the hand exactly as it was.
  void _show(
    List<List<PlayingCard>> sets, {
    required ShowKind kind,
    required int requiredCount,
    required bool Function(List<PlayingCard>) isValidSet,
  }) {
    if (hasSeenJoker) {
      throw StateError('Already showed and saw the joker');
    }
    if (!_hasDrawn) {
      throw StateError('Must draw before showing');
    }
    if (sets.length != requiredCount) {
      throw ArgumentError.value(
        sets.length,
        'sets',
        'must show exactly $requiredCount',
      );
    }
    for (final set in sets) {
      if (!isValidSet(set)) {
        throw ArgumentError.value(set, 'sets', 'contains an invalid set');
      }
    }

    // Remove from a copy so 2 copies of a card are only accepted if the
    // hand really holds 2 copies.
    final remaining = [..._cards];
    for (final card in sets.expand((set) => set)) {
      if (!remaining.remove(card)) {
        throw ArgumentError.value(card, 'sets', 'uses a card not in the hand');
      }
    }
    if (remaining.isEmpty) {
      throw ArgumentError('Showing must leave a card to discard');
    }

    _cards
      ..clear()
      ..addAll(remaining);
    _shownSets.addAll(sets.map((set) => [...set]));
    _showKind = kind;
  }
}
