import '../../engine/card.dart';
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

  /// A message to show the player, such as why a move wasn't allowed.
  final String? notice;

  /// Goes up with every new [notice], so repeating the same message still
  /// counts as new.
  final int noticeId;

  /// The selected card, if exactly one is selected.
  HandCard? get singleSelected => selected.length == 1
      ? hand.firstWhere((c) => c.id == selected.single)
      : null;

  TableState copyWith({
    TableView? view,
    List<HandCard>? hand,
    Set<int>? selected,
    List<List<PlayingCard>>? Function()? openingChoice,
    String? notice,
  }) => TableState(
    view: view ?? this.view,
    hand: hand ?? this.hand,
    selected: selected ?? this.selected,
    openingChoice: openingChoice != null ? openingChoice() : this.openingChoice,
    notice: notice ?? this.notice,
    noticeId: notice != null ? noticeId + 1 : noticeId,
  );
}
