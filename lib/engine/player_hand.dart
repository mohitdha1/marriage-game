import 'card.dart';
import 'joker.dart';
import 'melds.dart';

/// How a player earned the right to see the joker.
enum ShowKind {
  /// Showed 3 pure sets (each a pure sequence or a tunnella), counting any
  /// tunnellas from the opening show.
  pureSets,

  /// Showed 7 doublees, and plays the dublee game from then on.
  doublees,
}

/// One player's cards and their side of the round:
///
/// 1. **Opening show**, once, right after the deal: every tunnella dealt to
///    the player is laid down (up to 3 — if they hold more, they pick which 3).
///    Only these tunnellas earn tunnella bonus points, and they count toward
///    the 3 pure sets needed to see the joker.
/// 2. **Turns:** draw, optionally show, then discard. If the player already
///    holds the rest of their 3 pure sets from the deal, they may also show
///    them before their first draw.
///
/// Which player's turn it is, and where the drawn card comes from, are
/// decided by the round, not here.
///
/// Until a player shows, they haven't "seen" the joker: they can't use wild
/// cards, and [visibleJokers] hides the round's jokers from them.
class PlayerHand {
  PlayerHand(Iterable<PlayingCard> cards) : _cards = [...cards];

  static const pureSetsToShow = 3;
  static const doubleesToShow = 7;
  static const maxOpeningTunnellas = 3;

  final List<PlayingCard> _cards;
  final List<List<PlayingCard>> _openingTunnellas = [];
  final List<List<PlayingCard>> _shownSets = [];
  final List<PlayingCard> _keptAside = [];
  bool _hasOpened = false;
  bool _hasMadeFirstDraw = false;
  bool _hasDrawn = false;
  ShowKind? _showKind;

  /// Cards still held, not counting any that have been shown.
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  /// Tunnellas laid down in the opening show; empty until then, or if the
  /// player was dealt none.
  List<List<PlayingCard>> get openingTunnellas =>
      _unmodifiable(_openingTunnellas);

  /// Sets laid down when the player saw the joker, not counting
  /// [openingTunnellas]; empty until then.
  List<List<PlayingCard>> get shownSets => _unmodifiable(_shownSets);

  /// Printed jokers the player picked as the tiplu, kept aside: maal at the
  /// end, never part of a set.
  List<PlayingCard> get keptAside => List.unmodifiable(_keptAside);

  /// Whether the opening show has been made.
  bool get hasOpened => _hasOpened;

  /// Whether the player has drawn this turn and still owes a discard.
  bool get hasDrawn => _hasDrawn;

  /// How the player showed, or `null` if they haven't yet.
  ShowKind? get showKind => _showKind;

  bool get hasSeenJoker => _showKind != null;

  /// How many pure sets [showPureSets] needs, after counting opening
  /// tunnellas.
  int get pureSetsStillNeeded => pureSetsToShow - _openingTunnellas.length;

  /// The round's [jokers] if this player has seen them, otherwise `null`.
  Jokers? visibleJokers(Jokers jokers) => hasSeenJoker ? jokers : null;

  /// Makes the opening show, right after the deal and before the player's
  /// first draw. [tunnellas] must be every tunnella in the hand, or exactly
  /// 3 of them if the hand holds more than 3. Pass an empty list when the
  /// player was dealt no tunnellas.
  void showOpeningTunnellas(List<List<PlayingCard>> tunnellas) {
    if (_hasOpened) {
      throw StateError('Already made the opening show');
    }
    for (final tunnella in tunnellas) {
      if (!isOpeningTunnella(tunnella)) {
        throw ArgumentError.value(
          tunnella,
          'tunnellas',
          'contains a set that is not a tunnella',
        );
      }
    }

    final held = _countTunnellas(_cards);
    final required = held < maxOpeningTunnellas ? held : maxOpeningTunnellas;
    if (tunnellas.length != required) {
      throw ArgumentError.value(
        tunnellas.length,
        'tunnellas',
        'must show all $held tunnellas held, up to $maxOpeningTunnellas',
      );
    }

    final remaining = _removeAll(tunnellas);
    _cards
      ..clear()
      ..addAll(remaining);
    _openingTunnellas.addAll(tunnellas.map((t) => [...t]));
    _hasOpened = true;
  }

  /// Keeps [card] aside, after the player picked it as the tiplu when it
  /// can't be one (a printed joker). Only the player showing first picks, so they've seen
  /// the joker.
  void keepAside(PlayingCard card) {
    if (!hasSeenJoker) {
      throw StateError('Only a player who has shown picks the tiplu');
    }
    _keptAside.add(card);
  }

  /// Starts the player's turn by adding [card] to their hand.
  void draw(PlayingCard card) {
    if (!_hasOpened) {
      throw StateError('Must make the opening show before drawing');
    }
    if (_hasDrawn) {
      throw StateError('Already drew this turn; discard first');
    }
    _cards.add(card);
    _hasDrawn = true;
    _hasMadeFirstDraw = true;
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

  /// Shows [pureSetsStillNeeded] pure sets — each a pure sequence (3 or more
  /// cards) or a tunnella, one of which may use the Superman for a card
  /// (see [isShowPureSet]) — to see the joker. Allowed after drawing, or
  /// before the player's first draw if the sets came straight from the deal.
  /// If 3 opening tunnellas were shown, pass an empty list.
  void showPureSets(List<List<PlayingCard>> sets) {
    _show(
      sets,
      kind: ShowKind.pureSets,
      requiredCount: pureSetsStillNeeded,
      isValidSet: isShowPureSet,
      allowedBeforeFirstDraw: true,
    );
  }

  /// Shows exactly 7 doublees, after drawing, to see the joker. The
  /// Superman pairs with any card (see [isShowDoublee]).
  void showDoublees(List<List<PlayingCard>> pairs) {
    _show(
      pairs,
      kind: ShowKind.doublees,
      requiredCount: doubleesToShow,
      isValidSet: isShowDoublee,
      allowedBeforeFirstDraw: false,
    );
  }

  /// Checks everything before changing anything, so a rejected show leaves
  /// the hand exactly as it was.
  void _show(
    List<List<PlayingCard>> sets, {
    required ShowKind kind,
    required int requiredCount,
    required bool Function(List<PlayingCard>) isValidSet,
    required bool allowedBeforeFirstDraw,
  }) {
    if (hasSeenJoker) {
      throw StateError('Already showed and saw the joker');
    }
    if (!_hasOpened) {
      throw StateError('Must make the opening show first');
    }
    final isEarlyShow = allowedBeforeFirstDraw && !_hasMadeFirstDraw;
    if (!_hasDrawn && !isEarlyShow) {
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

    final remaining = _removeAll(sets);
    if (_hasDrawn && remaining.isEmpty) {
      throw ArgumentError('Showing must leave a card to discard');
    }

    _cards
      ..clear()
      ..addAll(remaining);
    _shownSets.addAll(sets.map((set) => [...set]));
    _showKind = kind;
  }

  /// Returns a copy of the hand with every card in [sets] removed. Removing
  /// one copy at a time means 2 copies of a card are only accepted if the
  /// hand really holds 2 copies.
  List<PlayingCard> _removeAll(List<List<PlayingCard>> sets) {
    final remaining = [..._cards];
    for (final card in sets.expand((set) => set)) {
      if (!remaining.remove(card)) {
        throw ArgumentError.value(card, 'sets', 'uses a card not in the hand');
      }
    }
    return remaining;
  }
}

/// How many separate tunnellas [cards] could make: every 3 copies of the same
/// card is one.
int _countTunnellas(List<PlayingCard> cards) {
  final copies = <PlayingCard, int>{};
  for (final card in cards) {
    copies[card] = (copies[card] ?? 0) + 1;
  }
  return copies.values.fold(0, (total, n) => total + n ~/ 3);
}

List<List<PlayingCard>> _unmodifiable(List<List<PlayingCard>> sets) =>
    List.unmodifiable(sets.map(List<PlayingCard>.unmodifiable));
