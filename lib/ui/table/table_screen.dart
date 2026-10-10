import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/card.dart';
import '../../engine/hand_arrangement.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/table_event.dart';
import '../scoreboard/scoreboard_screen.dart';
import '../settings/settings.dart';
import '../sound/sound_effects.dart';
import '../state/table_controller.dart';
import '../state/table_state.dart';
import '../state/table_view.dart';
import '../theme/table_felt.dart';
import '../theme/table_theme.dart';
import 'card_face_art.dart';
import 'card_flights.dart';
import 'card_view.dart';
import 'hand_fan.dart';
import 'joker_reveal.dart';
import 'opening_picker.dart';
import 'move_log.dart';
import 'opponent_seat.dart';
import 'set_chips.dart';
import 'suit_icon.dart';
import 'table_center.dart';
import 'tiplu_picker.dart';
import 'win_celebration.dart';

/// The main game screen, in landscape: opponents around the top and sides
/// (the one whose turn it is glows), the stock and discard pile in the
/// middle, and the human player's hand fanned along the bottom.
///
/// Under the piles, a status line says what to do next, and buttons appear
/// when they're useful: Group and Show to show sets and see the joker, Win to
/// finish the round. Moves the engine refuses pop up with its reason.
///
/// Cards glide between the piles, the hand and the seats as moves are made
/// (see [CardFlightLayer]), unless the device asks for reduced motion.
class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  /// Room kept clear on either side of the status line, for the seats and,
  /// lower down, the laid-down sets and action buttons.
  static const _sideClearance = 200.0;

  final _anchors = TableAnchors();
  final _flights = GlobalKey<CardFlightLayerState>();
  final _handCardKeys = <int, GlobalKey>{};

  /// Hand cards still in the air: drawn, but not landed yet.
  final _arriving = <int>{};

  /// Discards still in the air. Until they've all landed, the discard pile
  /// shows [_pileShowing] (nothing when `null`): what was on it before, then
  /// each discard as it lands.
  var _discardsFlying = 0;
  PlayingCard? _pileShowing;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  GlobalKey _handCardKey(int id) =>
      _handCardKeys.putIfAbsent(id, GlobalKey.new);

  /// Where the player let go of the card they're discarding by a drag or a
  /// flick, so its flight to the pile starts from there.
  Offset? _releasedAt;

  /// Discards [cardId], let go at [at] by a drag onto the pile or a flick.
  /// If a discard isn't allowed now, the controller says why and the card
  /// glides back to its place in the hand.
  void _discardReleased(int cardId, Offset at) {
    _releasedAt = at;
    unawaited(ref.read(tableProvider.notifier).discard(cardId));
    _releasedAt = null;
    if (ref.read(tableProvider).hand.any((c) => c.id == cardId)) {
      _snapBack(cardId, at);
    }
  }

  /// Glides [cardId] from [from] back to its place in the hand, after a
  /// drag that didn't end in a move.
  void _snapBack(int cardId, Offset from) {
    final layer = _flights.currentState;
    final card = ref
        .read(tableProvider)
        .hand
        .where((c) => c.id == cardId)
        .firstOrNull;
    if (_reduceMotion || layer == null || card == null) return;
    setState(() => _arriving.add(cardId));
    layer.fly(
      fromPoint: from,
      to: _handCardKey(cardId),
      face: card.card,
      onLanded: () {
        if (mounted) setState(() => _arriving.remove(cardId));
      },
    );
  }

  var _firstDealShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first round was dealt before the screen opened.
    if (_firstDealShown) return;
    _firstDealShown = true;
    precacheCourtArt(context);
    if (!_reduceMotion) _deal(ref.read(tableProvider));
  }

  /// Deals [state]'s hands from the stock: a card at a time to each player
  /// in turn, round the table, with the player's own cards appearing in
  /// their hand as they land.
  void _deal(TableState state) {
    final hand = state.hand.map((c) => c.id).toList();
    _arriving.addAll(hand);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final layer = _flights.currentState;
      if (!mounted || layer == null) {
        if (mounted) setState(() => _arriving.removeAll(hand));
        return;
      }
      final seats = state.view.opponents.map((o) => o.seat).toList();
      final dealt = hand.length * (seats.length + 1);
      // A full deal takes about the same time however many play.
      final gap = Duration(microseconds: _dealTime.inMicroseconds ~/ dealt);
      var delay = Duration.zero;
      for (final id in hand) {
        for (final seat in seats) {
          layer.fly(
            from: _anchors.stock,
            to: _anchors.seat(seat),
            delay: delay,
          );
          delay += gap;
        }
        layer.fly(
          from: _anchors.stock,
          to: _handCardKey(id),
          delay: delay,
          onLanded: () {
            if (mounted) setState(() => _arriving.remove(id));
          },
        );
        delay += gap;
      }
    });
  }

  /// How long dealing a round takes, not counting the last card's flight.
  static const _dealTime = Duration(milliseconds: 1500);

  /// Animates the moves in [next] that weren't in [previous]: each draw and
  /// discard glides from where it came from to where it went, one after
  /// another.
  void _animateMoves(TableState? previous, TableState next) {
    if (previous == null || _reduceMotion) return;
    if (previous.roundNumber != next.roundNumber) {
      _handCardKeys.clear();
      setState(() {
        _arriving.clear();
        _discardsFlying = 0;
        _deal(next);
      });
      return;
    }
    final fresh = next.view.events.skip(previous.view.events.length).toList();
    if (fresh.isEmpty) return;
    final releasedAt = _releasedAt;
    _releasedAt = null;

    // Hide what hasn't arrived yet in this very frame, then launch the
    // flights once the new layout is in place.
    final newest = next.hand.isEmpty ? null : next.hand.last;
    final humanDraws = fresh.any((e) => e is DrewCard && e.seat == humanSeat);
    final discards = fresh
        .where((e) => e is DiscardedCard || e is WonRound)
        .length;
    final pileTaken = fresh.any(
      (e) => e is DrewCard && e.source == DrawSource.discardPile,
    );
    setState(() {
      if (humanDraws && newest != null) _arriving.add(newest.id);
      if (discards > 0) {
        if (_discardsFlying == 0) {
          _pileShowing = pileTaken ? null : previous.view.topDiscard;
        }
        _discardsFlying += discards;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final layer = _flights.currentState;
      if (!mounted || layer == null) return;
      var delay = Duration.zero;
      for (final event in fresh) {
        switch (event) {
          case DrewCard(:final seat, :final source, :final card):
            final from = source == DrawSource.stock
                ? _anchors.stock
                : _anchors.discardPile;
            if (seat == humanSeat && newest != null) {
              layer.fly(
                from: from,
                to: _handCardKey(newest.id),
                face: newest.card,
                delay: delay,
                onLanded: () {
                  if (mounted) setState(() => _arriving.remove(newest.id));
                },
              );
            } else {
              layer.fly(
                from: from,
                to: _anchors.seat(seat),
                face: card,
                delay: delay,
              );
            }
            delay += cardFlightTime;
          case DiscardedCard(:final seat, :final card) ||
              WonRound(:final seat, :final card):
            final yours = seat == humanSeat;
            layer.fly(
              from: yours ? _anchors.hand : _anchors.seat(seat),
              fromPoint: yours ? releasedAt : null,
              to: _anchors.discardPile,
              face: card,
              delay: delay,
              onLanded: () {
                if (!mounted) return;
                setState(() {
                  if (_discardsFlying > 0) _discardsFlying--;
                  _pileShowing = card;
                });
              },
            );
            delay += cardFlightTime;
          case OpenedTunnellas() || ShowedSets() || StockReshuffled():
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tableProvider, _animateMoves);
    final state = ref.watch(tableProvider);
    final table = state.view;
    final controller = ref.read(tableProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final sounds = ref.read(soundEffectsProvider);

    // When a round ends, give the player a moment to see the winning move,
    // then show the scores.
    ref.listen(tableProvider.select((s) => s.roundScores.length), (
      previous,
      next,
    ) {
      if (next <= (previous ?? 0)) return;
      Future.delayed(scoreboardDelay, () {
        if (context.mounted) _openScoreboard(context);
      });
    });

    ref.listen(tableProvider.select((s) => s.noticeId), (previous, next) {
      final notice = ref.read(tableProvider).notice;
      if (notice == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: SuitText(notice),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });

    return Scaffold(
      body: TableFelt(
        rim: true,
        // Clear of the rim, wherever the screen's own insets are narrower.
        child: SafeArea(
          minimum: const EdgeInsets.all(TableFelt.rimWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxHeight * 0.16).clamp(
                40.0,
                100.0,
              );
              final seats = seatAlignments(table.opponents.length);
              final choice = state.openingChoice;
              final jokers = table.yourJokers;
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    for (var i = 0; i < table.opponents.length; i++)
                      Align(
                        alignment: seats[i],
                        child: KeyedSubtree(
                          key: _anchors.seat(table.opponents[i].seat),
                          child: OpponentSeat(
                            seat: table.opponents[i],
                            isCurrentTurn:
                                table.winner == null &&
                                table.currentSeat == table.opponents[i].seat,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Row(
                        key: const Key('top-left-buttons'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopButton(
                            key: const Key('back-button'),
                            tooltip: 'Leave the table',
                            icon: Icons.arrow_back,
                            onPressed: () => _leave(context, table),
                          ),
                          _TopButton(
                            key: const Key('log-button'),
                            tooltip: 'Log of this round\'s moves',
                            icon: Icons.history,
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              builder: (_) => MoveLog(
                                events: table.events,
                                nameOf: (seat) => state.seatNames[seat],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Row(
                        key: const Key('top-right-items'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopButton(
                            key: const Key('scores-button'),
                            tooltip: 'Scores',
                            icon: Icons.leaderboard,
                            onPressed: () => _openScoreboard(context),
                          ),
                          const SizedBox(width: 6),
                          _JokerChip(table: table),
                        ],
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.2),
                      child: Column(
                        key: const Key('table-centre'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TableCenter(
                            stockCount: table.stockCount,
                            topDiscard: _discardsFlying > 0
                                ? _pileShowing
                                : table.topDiscard,
                            stockKey: _anchors.stock,
                            discardKey: _anchors.discardPile,
                            cardWidth: cardWidth,
                            onStockTap: () => controller.draw(DrawSource.stock),
                            onDiscardPileTap: controller.tapDiscardPile,
                            onCardDropped: _discardReleased,
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            // Keep clear of the seats at the sides.
                            constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth - 2 * _sideClearance,
                            ),
                            child: Text(
                              statusLine(state),
                              key: const Key('status-line'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Just above the hand, clear of the space a selected card
                    // lifts into: laid-down sets on the left, buttons on the
                    // right.
                    Align(
                      alignment: const Alignment(-1, 0.05),
                      child: Row(
                        key: const Key('hand-tools'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TopButton(
                            key: const Key('sort-button'),
                            tooltip: 'Sort by suit, then rank',
                            icon: Icons.sort,
                            onPressed: controller.sortHand,
                          ),
                          if (table.you.laidDown.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _LaidDownSets(sets: table.you.laidDown),
                          ],
                        ],
                      ),
                    ),
                    Align(
                      alignment: const Alignment(1, 0.1),
                      child: _ActionBar(state: state, controller: controller),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: HandFan(
                        key: _anchors.hand,
                        hiddenIds: _arriving,
                        cardKey: _handCardKey,
                        cards: state.hand,
                        selected: state.selected,
                        groupOf: state.groupOf,
                        jokers: jokers,
                        cardWidth: cardWidth,
                        onCardTap: (id) {
                          sounds.play(Sfx.select);
                          controller.toggleSelected(id);
                        },
                        onDraw: controller.draw,
                        onReorder: controller.moveCard,
                        onFlick: _discardReleased,
                        onDropMissed: _snapBack,
                      ),
                    ),
                    // Badges over the hand's lower corners; taps go through
                    // to the cards.
                    if (maalOf(state.handProgress) case final maal?)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _CornerBadge(
                          key: const Key('maal-badge'),
                          text: 'Maal $maal',
                        ),
                      ),
                    if (state.handProgress case final progress?
                        when settings.handHelper)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: _CornerBadge(
                          key: const Key('hand-helper'),
                          text: handHelperText(progress),
                        ),
                      ),
                    Positioned.fill(
                      child: CardFlightLayer(
                        key: _flights,
                        cardWidth: cardWidth,
                      ),
                    ),
                    if (table.winner case final winner?)
                      Positioned.fill(
                        child: WinCelebration(
                          winnerName: winner.name,
                          youWon: winner.seat == table.you.seat,
                        ),
                      ),
                    if (choice != null)
                      _Overlay(
                        child: OpeningPicker(
                          tunnellas: choice,
                          onConfirm: controller.chooseOpeningTunnellas,
                        ),
                      ),
                    if (state.pickingTiplu)
                      _Overlay(
                        child: TipluPicker(
                          stockCount: table.stockCount,
                          onPick: controller.pickTiplu,
                          onCancel: controller.cancelTipluPick,
                        ),
                      ),
                    if (state.revealingJoker && jokers != null)
                      _Overlay(
                        child: JokerReveal(
                          jokers: jokers,
                          onDone: controller.dismissReveal,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Makes the phone's back gesture ask before leaving a round that's still
/// being played, just like the table's Back button.
class LeaveGuard extends ConsumerWidget {
  const LeaveGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref.read(tableProvider).view);
      },
      child: child,
    );
  }
}

/// Leaves the table for the home screen, checking first if a round is
/// still being played.
Future<void> _leave(BuildContext context, TableView table) async {
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return;
  if (table.winner == null) {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('leave-dialog'),
        title: const Text('Leave the table?'),
        content: const Text(
          'This match will end. Coins from rounds you\'ve finished are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            key: const Key('leave-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave != true) return;
  }
  navigator.pop();
}

/// How long the table stays on screen after a round ends before the
/// scoreboard opens.
const scoreboardDelay = Duration(milliseconds: 1500);

void _openScoreboard(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const ScoreboardScreen()));
}

/// What the human player should do next, in a few words.
String statusLine(TableState state) {
  final table = state.view;
  final winner = table.winner;
  if (winner != null) return '${winner.name} won the round.';
  if (state.openingChoice != null) return 'Choose your opening tunnellas.';
  if (!table.isYourTurn) {
    final thinking = table.opponents.where(
      (seat) => seat.seat == table.currentSeat,
    );
    return thinking.isEmpty
        ? 'Waiting for the other players…'
        : '${thinking.single.name} is thinking…';
  }
  if (!table.youHaveDrawn) return 'Your turn: draw a card.';
  if (table.youHaveSeenJoker) return 'Discard a card, or win.';
  return 'Select a card to discard.';
}

/// The hand helper's summary of [progress]: progress toward showing before
/// the joker is seen, and toward winning after.
String handHelperText(HandProgress progress) => switch (progress) {
  ShowProgress(:final pureSets, :final pureSetsNeeded, :final doublees)
      when pureSets >= pureSetsNeeded =>
    'Ready to show · Dublees ${min(doublees, PlayerHand.doubleesToShow)}/'
        '${PlayerHand.doubleesToShow}',
  ShowProgress(:final pureSets, :final pureSetsNeeded, :final doublees) =>
    'Sets $pureSets/$pureSetsNeeded · Dublees '
        '${min(doublees, PlayerHand.doubleesToShow)}/'
        '${PlayerHand.doubleesToShow}',
  WinProgress(:final setsMade, :final unmatched) =>
    '$setsMade sets · $unmatched unmatched',
  DubleeProgress(:final doublees, :final doubleesNeeded) =>
    'Dublees $doublees/$doubleesNeeded',
};

/// The hand's maal points, once the player has seen the joker.
int? maalOf(HandProgress? progress) => switch (progress) {
  WinProgress(:final maal) || DubleeProgress(:final maal) => maal,
  ShowProgress() || null => null,
};

/// A compact round icon button for the top of the table.
class _TopButton extends StatelessWidget {
  const _TopButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

/// A small read-only label over a corner of the hand.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: TableTheme.of(context).panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The buttons that make sense right now: grouping and showing sets before
/// the joker is seen, and winning after.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.controller});

  final TableState state;
  final TableController controller;

  @override
  Widget build(BuildContext context) {
    final table = state.view;
    final selected = state.singleSelected;
    final buttons = [
      if (!table.youHaveSeenJoker && state.selected.length >= 2)
        _button('group-button', 'Group', controller.groupSelected),
      if (state.groups.isNotEmpty)
        _button('clear-groups-button', 'Ungroup', controller.clearGroups),
      if (!table.youHaveSeenJoker &&
          table.isYourTurn &&
          state.groups.isNotEmpty)
        _button('show-button', 'Show', controller.showGroups),
      if (table.youHaveSeenJoker && table.isYourTurn && table.youHaveDrawn)
        _button(
          'win-button',
          'Win',
          selected != null && state.winningDiscards.contains(selected.id)
              ? controller.declareWin
              : null,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('action-bar'),
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final button in buttons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: button,
            ),
        ],
      ),
    );
  }

  Widget _button(String key, String label, VoidCallback? onPressed) =>
      FilledButton.tonal(
        key: Key(key),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(label),
      );
}

/// The joker in the top corner, as a small card: the tiplu face up once the
/// human player has seen it, or face down while it's picked but hidden from
/// them. Kept to a card's width so it never crowds the seats.
class _JokerChip extends StatelessWidget {
  const _JokerChip({required this.table});

  final TableView table;

  @override
  Widget build(BuildContext context) {
    final jokers = table.yourJokers;
    if (jokers == null && !table.isJokerChosen) return const SizedBox.shrink();
    return Tooltip(
      message: jokers == null
          ? 'The joker has been picked; show your sets to see it'
          : 'Joker: ${jokers.tiplu}',
      child: Container(
        key: const Key('joker-chip'),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: jokers == null
            ? const CardBack(width: 28)
            : CardFace(jokers.tiplu, width: 28, wild: true),
      ),
    );
  }
}

/// The human player's laid-down sets, as chips above their hand.
class _LaidDownSets extends StatelessWidget {
  const _LaidDownSets({required this.sets});

  final List<List<PlayingCard>> sets;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('your-laid-down-sets'),
      constraints: const BoxConstraints(maxWidth: 220),
      child: SetChips(sets, direction: Axis.horizontal),
    );
  }
}

/// Dims the table behind a dialog-like panel.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: Center(child: child),
      ),
    );
  }
}

/// Where each opponent sits, clockwise from the human player's left, for 1
/// to 4 opponents.
List<Alignment> seatAlignments(int opponentCount) => switch (opponentCount) {
  1 => const [Alignment.topCenter],
  2 => const [Alignment(-0.5, -1), Alignment(0.5, -1)],
  3 => const [Alignment(-1, -0.4), Alignment.topCenter, Alignment(1, -0.4)],
  _ => const [
    Alignment(-1, -0.4),
    Alignment(-0.4, -1),
    Alignment(0.4, -1),
    Alignment(1, -0.4),
  ],
};
