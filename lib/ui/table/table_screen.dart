import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/card.dart';
import '../../engine/hand_arrangement.dart';
import '../../engine/round.dart';
import '../../engine/scoring.dart';
import '../../engine/table_event.dart';
import '../guide/guide.dart';
import '../home/game_setup.dart';
import '../guide/table_guide.dart';
import '../scoreboard/scoreboard_screen.dart';
import '../settings/settings.dart';
import '../sound/sound_effects.dart';
import '../state/table_controller.dart';
import '../state/table_notifier.dart';
import '../state/table_state.dart';
import '../state/table_view.dart';
import '../telemetry/analytics.dart';
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
import 'pass_screen.dart';
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

  /// Room kept at each end of the row above the hand for the corner badges.
  static const _cornerBadgeRoom = 160.0;

  final _anchors = TableAnchors();
  final _statusLine = LayerLink();
  final _flights = GlobalKey<CardFlightLayerState>();
  final _handCardKeys = <int, GlobalKey>{};

  /// Hand cards still in the air: drawn, but not landed yet.
  final _arriving = <int>{};

  /// Discards still in the air. Until they've all landed, the discard pile
  /// shows [_pileShowing] (nothing when `null`): what was on it before, then
  /// each discard as it lands.
  var _discardsFlying = 0;
  PlayingCard? _pileShowing;

  /// A draw being dragged in from a pile, while the finger is down.
  _PileDrag? _pileDrag;

  /// The card that drag drew, once it's known, for the card under the
  /// finger to show.
  final _drawnCard = ValueNotifier<PlayingCard?>(null);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _drawnCard.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // A table opened on a round that's already over, as when a saved match
    // is picked up, goes straight to the scores.
    if (ref.read(tableProvider).view.winner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openScoreboard(context);
      });
    }
  }

  GlobalKey _handCardKey(int id) =>
      _handCardKeys.putIfAbsent(id, GlobalKey.new);

  /// Where the player let go of the card they're discarding by a drag or a
  /// flick, so its flight to the pile starts from there.
  Offset? _releasedAt;

  /// Discards [cardId], let go at [at] by a drag onto the pile or a flick.
  /// If a discard isn't allowed now, the controller says why and the card
  /// glides back to its place in the hand; so it does if the card is a
  /// joker and the player decides not to pay the penalty after all.
  Future<void> _discardReleased(int cardId, Offset at) async {
    if (!await _confirmDiscard(cardId)) {
      _snapBack(cardId, at);
      return;
    }
    if (!mounted) return;
    _releasedAt = at;
    unawaited(ref.read(tableProvider.notifier).discard(cardId));
    _releasedAt = null;
    if (ref.read(tableProvider).hand.any((c) => c.id == cardId)) {
      _snapBack(cardId, at);
    }
  }

  /// Taps on the discard pile: takes its card, or discards the selected
  /// one, asking first if that would cost the joker penalty.
  Future<void> _discardPileTapped() async {
    final selected = ref.read(tableProvider).singleSelected;
    if (selected != null && !await _confirmDiscard(selected.id)) return;
    if (!mounted) return;
    unawaited(ref.read(tableProvider.notifier).tapDiscardPile());
  }

  /// Whether to go ahead with discarding [cardId]: always, unless it would
  /// cost the joker penalty and the player backs out when asked.
  Future<bool> _confirmDiscard(int cardId) async {
    final controller = ref.read(tableProvider.notifier);
    if (!controller.discardCostsPenalty(cardId)) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('joker-discard-dialog'),
        title: const Text('Discard a joker?'),
        content: const Text(
          '${ScoringTable.jokerDiscardPenalty}-point penalty, paid to the '
          'round\'s winner.',
        ),
        actions: [
          TextButton(
            key: const Key('joker-discard-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('joker-discard-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return go ?? false;
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

  /// Draws from [source] as it starts being dragged, so the drawn card can
  /// be placed in the hand while the finger is still down.
  void _pileDragStarted(DrawSource source) {
    final drag = _PileDrag();
    _pileDrag = drag;
    _drawnCard.value = null;
    drag.drew = ref.read(tableProvider.notifier).draw(source);
  }

  /// The dragged card was let go at [at]. The drawn card glides from there
  /// to its place: where it was dropped if the hand took it ([placed]),
  /// otherwise the right end, where every draw lands. A card [flicked] up
  /// from the stock is discarded straight away instead; one from the
  /// discard pile can't go back the same turn, so it joins the hand. A
  /// refused draw glides back to its pile.
  void _pileDragEnded(
    DrawSource source,
    Offset at, {
    required bool placed,
    required bool flicked,
  }) {
    final drag = _pileDrag;
    _pileDrag = null;
    _drawnCard.value = null;
    if (drag == null) return;
    final id = drag.cardId;
    if (id == null) {
      // Sent to another device that hasn't answered yet: the card flies in
      // from the pile when it arrives.
      if (drag.drew) return;
      final layer = _flights.currentState;
      if (_reduceMotion || layer == null) return;
      layer.fly(
        fromPoint: at,
        to: source == DrawSource.stock ? _anchors.stock : _anchors.discardPile,
        face: source == DrawSource.discardPile
            ? ref.read(tableProvider).view.topDiscard
            : null,
      );
      return;
    }
    setState(() => _arriving.remove(id));
    if (flicked && !placed && source == DrawSource.stock) {
      unawaited(_discardReleased(id, at));
      return;
    }
    // Launched once the hand is laid out with the card in its new place.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _snapBack(id, at);
    });
  }

  /// The card drawn by the pile drag under way, the moment it appears in
  /// the hand: it stays hidden there, keeping its place open, while the
  /// finger carries it.
  void _catchDrawnCard(TableState? previous, TableState next) {
    final drag = _pileDrag;
    if (drag == null || drag.cardId != null || previous == null) return;
    final before = {for (final card in previous.hand) card.id};
    final drawn = next.hand.where((c) => !before.contains(c.id)).firstOrNull;
    if (drawn == null) return;
    setState(() {
      drag.cardId = drawn.id;
      _arriving.add(drawn.id);
    });
    _drawnCard.value = drawn.card;
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
    _catchDrawnCard(previous, next);
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
    final you = next.view.you.seat;
    // A card drawn by dragging a pile travels under the finger instead.
    final dragged = newest != null && newest.id == _pileDrag?.cardId;
    final humanDraws = fresh.any((e) => e is DrewCard && e.seat == you);
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
            if (seat == you && dragged) {
              // Nothing flies: the finger is carrying it.
            } else if (seat == you && newest != null) {
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
            final yours = seat == you;
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
          case OpenedTunnellas() ||
              ShowedSets() ||
              StockReshuffled() ||
              KeptAside():
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          TableFelt(
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
                  // The hand's cards are larger, with their bottoms running
                  // off the edge of the table.
                  final handCardWidth = (constraints.maxHeight * 0.24).clamp(
                    48.0,
                    130.0,
                  );
                  const handHidden = 0.25;
                  // Whether a first-time guide tip is showing above the
                  // hand.
                  final guiding =
                      guideStepFor(state, ref.watch(guideProvider)) != null;
                  // How far up the hand's cards reach.
                  final aboveHand =
                      handCardWidth / cardAspectRatio * (1 - handHidden) + 4;
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
                                offline: state.offlineSeats.contains(
                                  table.opponents[i].seat,
                                ),
                                isCurrentTurn:
                                    table.winner == null &&
                                    table.currentSeat ==
                                        table.opponents[i].seat,
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
                                onPressed: () => _leave(context, ref, table),
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
                              if (feltLabel(controller.mode, controller.stake)
                                  case final label?) ...[
                                Text(
                                  label,
                                  key: const Key('felt-label'),
                                  style: const TextStyle(
                                    color: Color(0x99FFFFFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              TableCenter(
                                stockCount: table.stockCount,
                                topDiscard: _discardsFlying > 0
                                    ? _pileShowing
                                    : table.topDiscard,
                                stockKey: _anchors.stock,
                                discardKey: _anchors.discardPile,
                                cardWidth: cardWidth,
                                onStockTap: () =>
                                    controller.draw(DrawSource.stock),
                                onDiscardPileTap: _discardPileTapped,
                                onCardDropped: _discardReleased,
                                onPileDragStarted: _pileDragStarted,
                                onPileDragEnded: _pileDragEnded,
                                drawnCard: _drawnCard,
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                // Keep clear of the seats at the sides.
                                constraints: BoxConstraints(
                                  maxWidth:
                                      constraints.maxWidth - 2 * _sideClearance,
                                ),
                                // The first-time guide's tips sit here.
                                child: CompositedTransformTarget(
                                  link: _statusLine,
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
                            ],
                          ),
                        ),
                        Align(
                          alignment: const Alignment(1, 0.1),
                          child: _ActionBar(
                            state: state,
                            controller: controller,
                          ),
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
                            cardWidth: handCardWidth,
                            hiddenBelow: handHidden,
                            onCardTap: (id) {
                              sounds.play(Sfx.select);
                              controller.toggleSelected(id);
                            },
                            placingId: _pileDrag?.cardId,
                            onPlaceDrawn: (slot) {
                              if (_pileDrag?.cardId case final id?) {
                                controller.moveCard(id, slot);
                              }
                            },
                            onReorder: controller.moveCard,
                            onFlick: _discardReleased,
                            onDropMissed: _snapBack,
                          ),
                        ),
                        // The sets the player has shown, as chips centred just
                        // above the hand, between the corner badges. A
                        // first-time guide tip borrows the space while it
                        // shows.
                        if (table.you.laidDown.isNotEmpty && !guiding)
                          Positioned(
                            left: _cornerBadgeRoom,
                            right: _cornerBadgeRoom,
                            bottom: aboveHand,
                            child: Center(
                              child: _LaidDownSets(sets: table.you.laidDown),
                            ),
                          ),
                        // Badges just above the hand's corners, clear of the
                        // cards; taps go through to anything underneath.
                        if (maalOf(state.handProgress) case final maal?)
                          Positioned(
                            left: 0,
                            bottom: aboveHand,
                            child: _CornerBadge(
                              key: const Key('maal-badge'),
                              text: 'Maal $maal',
                            ),
                          ),
                        if (state.handProgress case final progress?
                            when settings.handHelper && !guiding)
                          Positioned(
                            right: 0,
                            bottom: aboveHand,
                            child: _HandHelper(
                              key: const Key('hand-helper'),
                              progress: progress,
                            ),
                          ),
                        Positioned.fill(
                          child: CardFlightLayer(
                            key: _flights,
                            cardWidth: cardWidth,
                          ),
                        ),
                        Positioned.fill(
                          child: TableGuideLayer(statusLine: _statusLine),
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
                              mustPick: table.youMustPickTiplu,
                              again: table.youPickTipluAgain,
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
          // Among friends, the whole screen stays covered while the device
          // is passed, so nobody sees another's cards.
          if (state.passingTo case final seat?)
            PassScreen(
              name: state.seatNames[seat],
              color: Color(
                Settings.avatarColors[seat % Settings.avatarColors.length],
              ),
              since: movesSince(table.events, seat, (s) => state.seatNames[s]),
              choosingOpening: state.openingChoice != null,
              onReady: controller.takeOver,
            ),
        ],
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
        if (!didPop) _leave(context, ref, ref.read(tableProvider).view);
      },
      child: child,
    );
  }
}

/// Leaves the table for the home screen, checking first if a round is
/// still being played.
Future<void> _leave(
  BuildContext context,
  WidgetRef ref,
  TableView table,
) async {
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
    ref.read(analyticsProvider).gameQuitEarly();
  }
  ref.read(tableProvider.notifier).endMatch();
  navigator.pop();
}

/// A draw made by dragging a pile: whether the draw was made (or sent),
/// and the drawn card's id once it's in the hand.
class _PileDrag {
  bool drew = false;
  int? cardId;
}

/// How long the table stays on screen after a round ends before the
/// scoreboard opens.
const scoreboardDelay = Duration(milliseconds: 1500);

void _openScoreboard(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'scoreboard'),
      builder: (_) => const ScoreboardScreen(),
    ),
  );
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
  if (table.youHaveSeenJoker && !table.youHaveShownThisTurn) {
    return 'Discard a card, or win.';
  }
  if (table.youHaveShown && !table.youHaveSeenJoker) {
    return 'Discard a card to see the joker.';
  }
  return 'Select a card to discard.';
}

/// How many more sets (or, on the dublee route, doublees) the hand needs
/// to win, once the player has seen the joker; 0 when it can win this turn.
int? toWinOf(HandProgress? progress) => switch (progress) {
  WinProgress(:final setsToWin) => setsToWin,
  DubleeProgress(:final doubleesToWin) => doubleesToWin,
  ShowProgress() || null => null,
};

/// The to-win badge's text for [toWin] (see [toWinOf]).
String toWinText(int toWin) => toWin == 0 ? 'Ready to win!' : '$toWin to win';

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

/// A small read-only label over a corner of the hand. A [lit] badge is
/// drawn in the theme's accent colour, for a goal reached.
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({super.key, required this.text, this.lit = false});

  final String text;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = TableTheme.of(context);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: lit ? theme.accent : theme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: lit ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The hand helper in the hand's right corner. Before the joker is seen it
/// counts doublees and pure sequences toward the show, each lit once there
/// are enough; afterwards it counts down to the win.
class _HandHelper extends StatelessWidget {
  const _HandHelper({super.key, required this.progress});

  final HandProgress progress;

  @override
  Widget build(BuildContext context) {
    if (toWinOf(progress) case final toWin?) {
      return _CornerBadge(
        key: const Key('to-win'),
        text: toWinText(toWin),
        lit: toWin == 0,
      );
    }
    final show = progress as ShowProgress;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        _CornerBadge(
          key: const Key('dub-count'),
          text: 'Dub ${min(show.doublees, show.doubleesNeeded)}',
          lit: show.doublees >= show.doubleesNeeded,
        ),
        _CornerBadge(
          key: const Key('seq-count'),
          text: 'Seq ${show.pureSets}',
          lit: show.pureSets >= show.pureSetsNeeded,
        ),
      ],
    );
  }
}

/// The buttons that make sense right now: grouping and showing sets before
/// the joker is seen, and winning after.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.state, required this.controller});

  final TableState state;
  final TableNotifier controller;

  @override
  Widget build(BuildContext context) {
    final table = state.view;
    final selected = state.singleSelected;
    final buttons = [
      if (!table.youHaveShown && state.selected.length >= 2)
        _button('group-button', 'Group', controller.groupSelected),
      if (state.groups.isNotEmpty)
        _button('clear-groups-button', 'Ungroup', controller.clearGroups),
      if (!table.youHaveShown && table.isYourTurn && state.groups.isNotEmpty)
        _button('show-button', 'Show', controller.showGroups),
      if (table.youHaveSeenJoker &&
          !table.youHaveShownThisTurn &&
          table.isYourTurn &&
          table.youHaveDrawn)
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

/// The player's laid-down sets, as chips in a row (wrapping if there are
/// many) above their hand.
class _LaidDownSets extends StatelessWidget {
  const _LaidDownSets({required this.sets});

  final List<List<PlayingCard>> sets;

  @override
  Widget build(BuildContext context) {
    return SetChips(
      sets,
      key: const Key('your-laid-down-sets'),
      direction: Axis.horizontal,
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
