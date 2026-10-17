import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/card.dart';
import '../../engine/game_config.dart';
import '../../engine/melds.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../net/remote_session.dart';
import '../home/player_data_provider.dart';
import '../../net/wire.dart';
import '../telemetry/analytics.dart';
import 'table_notifier.dart';
import 'table_state.dart';

/// The link to the host, on a device that has joined a game. `null`
/// everywhere else; the joined game's table screen provides it.
final remoteSessionProvider = Provider<RemoteSession?>((ref) => null);

/// The table on a device that has joined a game hosted elsewhere. The host
/// plays the game; this sends the person's moves there and shows what the
/// host says they may see, keeping their own arrangement of the hand.
class RemoteTableController extends TableNotifier {
  late RemoteSession _host;
  late SeatUpdate _last;

  /// The match the table shows, from the host's latest update.
  int? _match;

  @override
  TableState build() {
    _host = ref.watch(remoteSessionProvider)!;
    _last = _host.latest!;
    final listening = _host.messages.listen(
      _onMessage,
      onDone: () => postNotice('Lost the connection to the host.'),
    );
    ref.onDispose(listening.cancel);
    final reconnecting = _host.connectionChanges.listen(
      (connected) => postNotice(
        connected ? 'Reconnected.' : 'Connection lost. Reconnecting…',
      ),
    );
    ref.onDispose(reconnecting.cancel);
    return _stateFor(_last, previous: null);
  }

  void _onMessage(WireMessage message) {
    switch (message) {
      case SeatUpdate():
        final previous = state;
        _last = message;
        state = _stateFor(message, previous: previous);
        // A round just finished counts toward the player's stats.
        if (message.roundScores.length > previous.roundScores.length) {
          final score = message.roundScores.last;
          final seat = message.view.you.seat;
          ref
              .read(analyticsProvider)
              .roundFinished(
                won: score.winner == seat,
                sawJoker: score.sawJoker[seat],
              );
          unawaited(
            ref
                .read(playerDataProvider.notifier)
                .recordGameResult(
                  won: score.winner == seat,
                  points: score.net[seat],
                ),
          );
        }
      case Refused(:final reason):
        postNotice(reason);
      case _:
        break;
    }
  }

  /// The table for [update], keeping the person's own arrangement from
  /// [previous] within a round.
  TableState _stateFor(SeatUpdate update, {required TableState? previous}) {
    final view = update.view;
    final sameRound =
        previous != null &&
        update.match == _match &&
        previous.roundNumber == update.roundNumber;
    _match = update.match;
    if (!sameRound) resetCardIds();
    final hand = reconcile(view.hand, sameRound ? previous.hand : const []);
    final ids = {for (final c in hand) c.id};

    // Seeing the joker just now: the shown sets have gone, and the reveal
    // opens.
    final justSaw =
        sameRound && !previous.view.youHaveSeenJoker && view.youHaveSeenJoker;
    final groups = justSaw || !sameRound
        ? const <List<int>>[]
        : [
            for (final group in previous.groups)
              group.where(ids.contains).toList(),
          ].where((group) => group.isNotEmpty).toList();

    final justWon = view.winner != null && previous?.view.winner == null;
    final notice = justWon
        ? (view.winner!.seat == view.you.seat
              ? 'You won the round!'
              : '${view.winner!.name} won the round.')
        : null;

    return TableState(
      view: view,
      hand: hand,
      selected: sameRound
          ? previous.selected.where(ids.contains).toSet()
          : const {},
      openingChoice: update.choosingOpening ? findTunnellas(view.hand) : null,
      groups: groups,
      pickingTiplu:
          view.youMustPickTiplu || (sameRound && previous.pickingTiplu),
      revealingJoker: justSaw || (sameRound && previous.revealingJoker),
      winningDiscards: {
        for (final handCard in hand)
          if (update.winningCards.contains(handCard.card)) handCard.id,
      },
      roundNumber: update.roundNumber,
      seatNames: update.seatNames,
      roundScores: update.roundScores,
      totals: update.totals,
      handProgress: update.handProgress,
      offlineSeats: update.offline.toSet(),
      notice: notice ?? previous?.notice,
      noticeId: (previous?.noticeId ?? 0) + (notice != null ? 1 : 0),
    );
  }

  @override
  bool draw(DrawSource source) {
    if (!checkYourTurn()) return false;
    _host.send(MoveDraw(source));
    return true;
  }

  @override
  Future<void> discard(int cardId) async {
    final card = cardWithId(cardId);
    if (card != null && checkYourTurn()) _host.send(MoveDiscard(card));
  }

  @override
  void submitOpening(List<List<PlayingCard>> tunnellas) =>
      _host.send(MoveOpenTunnellas(tunnellas));

  @override
  void submitShow({
    required ShowKind kind,
    required List<List<PlayingCard>> sets,
    required Set<int> ids,
    required int? tipluPosition,
  }) => _host.send(
    MoveShow(kind: kind, sets: sets, tipluPosition: tipluPosition),
  );

  @override
  void submitTipluPick(int position) => _host.send(MovePickTiplu(position));

  @override
  void submitWin(HandCard winning) => _host.send(MoveWin(winning.card));

  /// Only the host deals; the next round arrives from them.
  @override
  void startNextRound() => postNotice('The host deals the next round.');

  @override
  bool get dealsRounds => false;

  @override
  Future<void> get botsSettled => Future.value();

  @override
  bool get jokerPenaltyEnabled => _last.jokerPenalty;

  @override
  GameMode get mode => _last.mode;
}
