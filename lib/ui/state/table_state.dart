import '../../engine/card.dart';
import '../../engine/scoring.dart';
import 'table_view.dart';

/// One card in the human player's hand, with an [id] that stays the same
/// while it's held. Identical cards (a 3-deck shoe has three of each) get
/// different ids, so selecting one doesn't select its twins.
class HandCard {
  const HandCard(this.id, this.card);

  final int id;
  final PlayingCard card;

  @override
  bool operator ==(Object other) =>
      other is HandCard && other.id == id && other.card == card;

  @override
  int get hashCode => Object.hash(id, card);

  @override
  String toString() => '$card#$id';
}

/// Everything the table screen draws: the engine's [view] of the round, plus
/// state that only matters to this screen — the order the human player has
/// arranged their hand in, which cards they've selected, and any message to
/// show them.
class TableState {
  const TableState({
    required this.view,
    required this.hand,
    this.selected = const {},
    this.openingChoice,
    this.groups = const [],
    this.pickingTiplu = false,
    this.revealingJoker = false,
    this.winningDiscards = const {},
    this.botMoves = const {},
    this.roundNumber = 1,
    this.seatNames = const [],
    this.roundScores = const [],
    this.totals = const [],
    this.notice,
    this.noticeId = 0,
  });

  final TableView view;

  /// The human player's cards, in the order shown on screen.
  final List<HandCard> hand;

  /// Ids of the selected cards in [hand].
  final Set<int> selected;

  /// When the human player was dealt more than 3 tunnellas, the tunnellas to
  /// choose 3 from for the opening show; otherwise `null`. Play waits until
  /// they choose.
  final List<List<PlayingCard>>? openingChoice;

  /// Sets the human player has grouped, ready to show, as lists of card ids.
  /// Grouped cards sit together at the left of the hand.
  final List<List<int>> groups;

  /// Whether the human player is the first to show and is picking the tiplu
  /// from the stock. Their grouped sets are shown once they pick.
  final bool pickingTiplu;

  /// Whether the joker reveal is on screen, right after the human player
  /// has seen the joker.
  final bool revealingJoker;

  /// Ids of the cards that, if discarded now, would leave a winning hand.
  final Set<int> winningDiscards;

  /// Each bot's latest move in a few words, by seat, shown at its seat.
  final Map<int, String> botMoves;

  /// Which round of the match this is, counting from 1.
  final int roundNumber;

  /// Every player's name, by seat.
  final List<String> seatNames;

  /// The scores of every finished round in the match, oldest first.
  final List<RoundScore> roundScores;

  /// Each player's running match total, by seat.
  final List<int> totals;

  /// A message to show the player, such as why a move wasn't allowed.
  final String? notice;

  /// Goes up with every new [notice], so repeating the same message still
  /// counts as new.
  final int noticeId;

  /// The selected card, if exactly one is selected.
  HandCard? get singleSelected => selected.length == 1
      ? hand.firstWhere((c) => c.id == selected.single)
      : null;

  /// The group [cardId] belongs to, as an index into [groups], or `null`.
  int? groupOf(int cardId) {
    for (var i = 0; i < groups.length; i++) {
      if (groups[i].contains(cardId)) return i;
    }
    return null;
  }

  TableState copyWith({
    TableView? view,
    List<HandCard>? hand,
    Set<int>? selected,
    List<List<PlayingCard>>? Function()? openingChoice,
    List<List<int>>? groups,
    bool? pickingTiplu,
    bool? revealingJoker,
    Set<int>? winningDiscards,
    Map<int, String>? botMoves,
    List<RoundScore>? roundScores,
    List<int>? totals,
    String? notice,
  }) => TableState(
    view: view ?? this.view,
    hand: hand ?? this.hand,
    selected: selected ?? this.selected,
    openingChoice: openingChoice != null ? openingChoice() : this.openingChoice,
    groups: groups ?? this.groups,
    pickingTiplu: pickingTiplu ?? this.pickingTiplu,
    revealingJoker: revealingJoker ?? this.revealingJoker,
    winningDiscards: winningDiscards ?? this.winningDiscards,
    botMoves: botMoves ?? this.botMoves,
    roundNumber: roundNumber,
    seatNames: seatNames,
    roundScores: roundScores ?? this.roundScores,
    totals: totals ?? this.totals,
    notice: notice ?? this.notice,
    noticeId: notice != null ? noticeId + 1 : noticeId,
  );
}
