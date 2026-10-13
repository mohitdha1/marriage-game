import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bots/bot_personality.dart';
import '../../bots/bot_player.dart';
import '../../engine/card.dart';
import '../../engine/game_config.dart';
import '../../engine/hand_arrangement.dart';
import '../../engine/melds.dart';
import '../../engine/player_hand.dart';
import '../../engine/round.dart';
import '../../engine/scoring.dart';
import '../../engine/win_check.dart';
import '../../net/connection.dart';
import '../../net/game_host.dart' show Rejoin;
import '../../net/wire.dart';
import '../../data/stake_tables.dart';
import '../home/player_data_provider.dart';
import 'table_notifier.dart';
import 'table_state.dart';
import 'table_view.dart';

/// Who plays a match: one person against bots, several [people] passing
/// this device round the table, or a game hosted here for [remote] players
/// on other devices.
@immutable
class MatchSetup {
  /// One person against [playerCount] − 1 bots at [difficulty], each point
  /// worth one coin, or [stake] coins.
  const MatchSetup({
    this.playerCount = 5,
    this.difficulty = BotDifficulty.medium,
    this.stake,
    this.mode = GameMode.standard,
    this.jokerPenalty = true,
  }) : people = const [],
       remote = const {},
       rejoins = null;

  /// One person against [playerCount] − 1 bots at a stake [table]: each
  /// point is worth its stake in coins, and its bots play at its
  /// difficulty.
  MatchSetup.atTable(
    StakeTable table, {
    this.playerCount = 5,
    this.mode = GameMode.standard,
    this.jokerPenalty = true,
  }) : difficulty = table.difficulty,
       stake = table.stake,
       people = const [],
       remote = const {},
       rejoins = null;

  /// [people], named in seat order, taking turns on this device; no bots.
  MatchSetup.passAndPlay(
    List<String> people, {
    this.mode = GameMode.standard,
    this.jokerPenalty = true,
  }) : playerCount = people.length,
       difficulty = BotDifficulty.medium,
       stake = null,
       people = List.unmodifiable(people),
       remote = const {},
       rejoins = null;

  /// A game hosted on this device: its player at seat 0, [remote] players
  /// at their seats on other devices, and bots at [difficulty] in any other
  /// seat of [playerCount].
  MatchSetup.hosted({
    required String hostName,
    required this.playerCount,
    required Map<int, RemotePlayer> remote,
    this.difficulty = BotDifficulty.medium,
    this.rejoins,
    this.mode = GameMode.standard,
    this.jokerPenalty = true,
  }) : stake = null,
       people = [hostName],
       remote = Map.unmodifiable(remote);

  const MatchSetup._({
    required this.playerCount,
    required this.difficulty,
    required this.stake,
    required this.people,
    required this.remote,
    required this.rejoins,
    required this.mode,
    required this.jokerPenalty,
  });

  /// This setup played as [mode], with the joker-discard penalty
  /// [jokerPenalty]; the same setup if neither changes, so nothing watching
  /// it rebuilds for no reason.
  MatchSetup withRules({required GameMode mode, required bool jokerPenalty}) =>
      mode == this.mode && jokerPenalty == this.jokerPenalty
      ? this
      : MatchSetup._(
          playerCount: playerCount,
          difficulty: difficulty,
          stake: stake,
          people: people,
          remote: remote,
          rejoins: rejoins,
          mode: mode,
          jokerPenalty: jokerPenalty,
        );

  /// Players on other devices coming back after their link dropped.
  final Stream<Rejoin>? rejoins;

  /// Players on other devices, by seat.
  final Map<int, RemotePlayer> remote;

  /// How many play, people and bots together.
  final int playerCount;

  /// How well the bots play, when there are bots.
  final BotDifficulty difficulty;

  /// The stake table's coins per point, for a game at one; `null` for any
  /// other game.
  final int? stake;

  /// The people at this device, named by seat: everyone sharing it in pass
  /// and play, or just the host in a hosted game. Empty against bots, where
  /// the one person is "You".
  final List<String> people;

  /// How the rounds settle players who haven't seen the joker.
  final GameMode mode;

  /// Whether discarding a joker after seeing it costs a penalty (see
  /// [GameConfig.jokerDiscardPenaltyEnabled]).
  final bool jokerPenalty;

  bool get isPassAndPlay => people.isNotEmpty && remote.isEmpty;
}

/// A player on another device, and the link to it.
class RemotePlayer {
  RemotePlayer({required this.name, required this.connection});

  final String name;

  /// The link to their device: replaced if they come back after it drops,
  /// so a new match still reaches them.
  Connection connection;
}

/// Quick Play's setup: a full table of five against Medium bots.
const quickPlaySetup = MatchSetup();

/// The setup the next match starts with. Whatever starts a match chooses it:
/// Quick Play its own, a custom game the player's choices.
final matchSetupProvider = NotifierProvider<MatchSetupController, MatchSetup>(
  MatchSetupController.new,
);

class MatchSetupController extends Notifier<MatchSetup> {
  @override
  MatchSetup build() => quickPlaySetup;

  void choose(MatchSetup setup) => state = setup;
}

/// Settings for the current game: the players and house rules its setup
/// says. Tests override it.
final gameConfigProvider = Provider<GameConfig>((ref) {
  final setup = ref.watch(matchSetupProvider);
  return GameConfig(
    playerCount: setup.playerCount,
    mode: setup.mode,
    jokerDiscardPenaltyEnabled: setup.jokerPenalty,
  );
});

/// The random source for shuffling and bot choices. Tests override it with a
/// seeded [Random] so games are repeatable.
final randomProvider = Provider<Random>((ref) => Random());

/// Starts a new round. Tests override it to deal known cards.
final roundFactoryProvider = Provider<Round Function(int firstSeat)>((ref) {
  final config = ref.watch(gameConfigProvider);
  final random = ref.watch(randomProvider);
  return (firstSeat) =>
      Round.deal(config: config, random: random, firstSeat: firstSeat);
});

/// How well the bots play, as the game's setup says.
final botDifficultyProvider = Provider<BotDifficulty>(
  (ref) => ref.watch(matchSetupProvider).difficulty,
);

/// How long a bot "thinks" before each move: a slightly different pause
/// every time, so bots feel human. Tests override it with no pause.
final botThinkingTimeProvider = Provider<Duration Function()>((ref) {
  final random = ref.watch(randomProvider);
  return () => Duration(milliseconds: 700 + random.nextInt(701));
});

/// The seat the person using this device plays in a game against bots.
const humanSeat = 0;

/// The table as the person whose view it is sees it.
final tableProvider = NotifierProvider<TableNotifier, TableState>(
  TableController.new,
);

/// Sets up a fresh match with [setup], for the table opened next.
///
/// What's built from the setup is brought up to date here. Left until the
/// table is built, the update would land in the middle of a widget build,
/// where a change can't be announced.
void startMatchWith(WidgetRef ref, MatchSetup setup) {
  ref.read(matchSetupProvider.notifier).choose(setup);
  ref.read(roundFactoryProvider);
  ref.invalidate(tableProvider);
}

/// Owns the engine's [Round], applies the human player's moves to it, and
/// publishes a fresh [TableState] after each one. The engine stays the single
/// source of truth: every move goes through it, and when it refuses one, its
/// reason is shown to the player as a notice.
///
/// Every seat is a person or a [BotPlayer] with its own personality: one
/// person against bots, or several people passing this device round. Bots
/// play one at a time after a short thinking pause, and the table is
/// published after each bot's move, so the people watch the game unfold.
/// Nobody can move while a bot is thinking.
///
/// The table shows one person's view at a time: their hand, groups and
/// selection. Each person's are kept on their own [_Desk] while someone
/// else's turn is showing.
class TableController extends TableNotifier {
  late Round Function(int firstSeat) _newRound;
  late Round _round;
  late Map<int, BotPlayer> _bots;

  /// The seats people play at this device, and their names (empty against
  /// bots, where the one person is "You").
  late Set<int> _people;
  late List<String> _peopleNames;

  /// Whether people pass this device between turns, so the table is
  /// covered while it changes hands.
  late bool _passAndPlay;

  /// The stake table's coins per point, if the match is at one.
  int? _stake;

  /// Whose view the table shows: the person playing now, or the last one to
  /// play while bots take their turns.
  var _viewer = humanSeat;

  /// Everyone else's private table, kept while it isn't their view.
  final _desks = <int, _Desk>{};

  /// Players on other devices, by seat, and those of them still to choose
  /// their opening tunnellas this round.
  late Map<int, RemotePlayer> _remote;

  /// Tells this match apart from the one before it, for joined devices.
  late int _matchId;

  /// Players on other devices whose link has dropped, and the bots standing
  /// in for them until they're back.
  final _offline = <int>{};
  final _standIns = <int, BotPlayer>{};

  /// What's listening to each player on another device.
  final _listening = <int, StreamSubscription<WireMessage>>{};
  late Random _random;
  final _remoteChoosing = <int>{};
  late Duration Function() _thinkingTime;
  late MatchScore _match;
  Future<void>? _botsPlaying;
  var _firstSeat = 0;
  var _roundNumber = 1;
  var _roundRecorded = false;

  @override
  TableState build() {
    // Read once: a match keeps the setup it started with, even if the
    // choices for the next game change meanwhile.
    _newRound = ref.read(roundFactoryProvider);
    _thinkingTime = ref.watch(botThinkingTimeProvider);
    _firstSeat = 0;
    _roundNumber = 1;
    _round = _newRound(_firstSeat);
    _match = MatchScore(_round.hands.length);

    final setup = ref.read(matchSetupProvider);
    final seats = [for (var seat = 0; seat < _round.hands.length; seat++) seat];
    _peopleNames = setup.people;
    _passAndPlay = setup.isPassAndPlay;
    _stake = setup.stake;
    _people = setup.isPassAndPlay ? seats.toSet() : {humanSeat};
    _remote = setup.remote;
    _listening.clear();
    _remote.keys.forEach(_listenTo);
    ref.onDispose(() {
      for (final listening in _listening.values) {
        unawaited(listening.cancel());
      }
    });
    if (setup.rejoins case final rejoins?) {
      final listening = rejoins.listen(
        (rejoin) => _onRejoin(rejoin.seat, rejoin.connection),
      );
      ref.onDispose(listening.cancel);
    }

    // The same bots play every round of the match.
    final random = _random = ref.watch(randomProvider);
    _matchId = random.nextInt(1 << 30);
    final difficulty = ref.read(botDifficultyProvider);
    final botSeats = [
      for (final seat in seats)
        if (!_people.contains(seat) && !_remote.containsKey(seat)) seat,
    ];
    final personalities = BotPersonality.pick(botSeats.length, random);
    _bots = {
      for (var i = 0; i < botSeats.length; i++)
        botSeats[i]: BotPlayer(
          difficulty: difficulty,
          personality: personalities[i],
          random: random,
        ),
    };

    // Players on other devices see the first deal once it's in place.
    Future.microtask(_sendUpdates);
    return _setUpRound();
  }

  /// Deals the next round once the current one is over. The first player
  /// moves one seat round the table, and match totals carry on.
  @override
  void startNextRound() {
    if (!_round.isOver) return;
    _firstSeat = (_firstSeat + 1) % _round.hands.length;
    _roundNumber++;
    _round = _newRound(_firstSeat);
    state = _setUpRound();
    _sendUpdates();
  }

  /// Makes the opening shows for the newly dealt [_round] and returns its
  /// first state.
  TableState _setUpRound() {
    _botsPlaying = null;
    resetCardIds();
    _roundRecorded = false;
    _desks.clear();

    for (final MapEntry(key: seat, value: bot) in _bots.entries) {
      _round.showOpeningTunnellas(
        seat,
        bot.openingTunnellas(_round.hands[seat].cards),
      );
    }

    // Each person's tunnellas are shown for them, unless they hold more
    // than 3 and have to choose.
    final choosing = <int>[];
    for (final seat in _inTurnOrder(_people)) {
      final tunnellas = findTunnellas(_round.hands[seat].cards);
      if (tunnellas.length > PlayerHand.maxOpeningTunnellas) {
        choosing.add(seat);
        _desks[seat] = _Desk(openingChoice: tunnellas);
      } else {
        _round.showOpeningTunnellas(seat, tunnellas);
      }
    }
    // Players on other devices choose on their own screens.
    _remoteChoosing.clear();
    for (final seat in _remote.keys) {
      final tunnellas = findTunnellas(_round.hands[seat].cards);
      if (tunnellas.length <= PlayerHand.maxOpeningTunnellas) {
        _round.showOpeningTunnellas(seat, tunnellas);
      } else if (_offline.contains(seat)) {
        // Nobody's there to choose; the bot standing in opens with the
        // first three.
        _round.showOpeningTunnellas(
          seat,
          tunnellas.take(PlayerHand.maxOpeningTunnellas).toList(),
        );
      } else {
        _remoteChoosing.add(seat);
      }
    }
    // The view opens on the first person who has to choose, or else on the
    // first person to play.
    _viewer = choosing.isNotEmpty
        ? choosing.first
        : _inTurnOrder(_people).first;
    final desk = _desks.remove(_viewer) ?? _Desk();
    if (choosing.isEmpty && _remoteChoosing.isEmpty) {
      // If a bot goes first, start it once this first state is in place.
      Future.microtask(_advance);
    }

    return TableState(
      view: _snapshot(),
      hand: _heldFrom(desk.hand),
      openingChoice: desk.openingChoice,
      roundNumber: _roundNumber,
      seatNames: [
        for (var seat = 0; seat < _round.hands.length; seat++) _nameOf(seat),
      ],
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
      handProgress: _handProgress(),
      // Among friends, the round opens covered until whoever goes first has
      // the device.
      passingTo: _passAndPlay ? _viewer : null,
    );
  }

  @override
  void submitOpening(List<List<PlayingCard>> tunnellas) {
    final shown = _act(() => _round.showOpeningTunnellas(_viewer, tunnellas));
    if (!shown) return;
    state = state.copyWith(openingChoice: () => null);
    // Anyone else who has to choose goes next; then play begins.
    final stillChoosing = _inTurnOrder(
      _people,
    ).where((seat) => _desks[seat]?.openingChoice != null);
    if (stillChoosing.isNotEmpty) {
      _switchTo(stillChoosing.first);
    } else if (_remoteChoosing.isEmpty) {
      unawaited(_advance());
    }
  }

  @override
  void draw(DrawSource source) {
    if (!checkYourTurn()) return;
    _act(() => _round.draw(source));
  }

  /// Discards the card with [cardId] to end the turn; any bots then play
  /// until it's a person's turn again. The returned future completes once
  /// they have.
  @override
  Future<void> discard(int cardId) async {
    final card = cardWithId(cardId);
    if (card == null || !checkYourTurn()) return;
    if (_act(() => _round.discard(card), removing: {cardId})) {
      await _advance();
    }
  }

  @override
  Future<void> get botsSettled => _botsPlaying ?? Future.value();

  @override
  bool get jokerPenaltyEnabled => _round.config.jokerDiscardPenaltyEnabled;

  @override
  GameMode get mode => _round.config.mode;

  @override
  int? get stake => _stake;

  @override
  void submitShow({
    required ShowKind kind,
    required List<List<PlayingCard>> sets,
    required Set<int> ids,
    required int? tipluPosition,
  }) {
    final shown = _act(() {
      switch (kind) {
        case ShowKind.doublees:
          _round.showDoublees(sets, tipluPosition: tipluPosition);
        case ShowKind.pureSets:
          _round.showPureSets(sets, tipluPosition: tipluPosition);
      }
    }, removing: ids);
    if (shown) {
      state = state.copyWith(groups: [], revealingJoker: true);
      _offerPickAgain();
    }
  }

  @override
  void submitTipluPick(int position) {
    if (_act(() => _round.pickTiplu(position))) _offerPickAgain();
  }

  /// Opens the tiplu picker again if the person's pick was a printed joker.
  void _offerPickAgain() {
    if (state.view.youMustPickTiplu) {
      state = state.copyWith(pickingTiplu: true);
    }
  }

  @override
  void submitWin(HandCard winning) =>
      _act(() => _round.declareWin(winning.card), removing: {winning.id});

  /// Runs [move] against the engine, turning a refused move into a notice,
  /// then publishes the new state. [removing] names the hand cards the move
  /// takes out of the hand, so the right copy goes when there are
  /// duplicates. Returns whether the engine accepted the move.
  bool _act(void Function() move, {Set<int> removing = const {}}) {
    var notice = _tryMove(move);
    final accepted = notice == null;
    if (accepted) notice = _winNotice();
    _publish(notice: notice, removed: accepted ? removing : const {});
    return accepted;
  }

  /// Runs [move] against the engine, returning the engine's reason if it
  /// refuses, or `null` if it accepts.
  String? _tryMove(void Function() move) {
    try {
      move();
      return null;
    } on ArgumentError catch (e) {
      return _explain(e);
    } on StateError catch (e) {
      return e.message;
    }
  }

  /// Who won, once the round is over.
  String? _winNotice() => switch (_round.winner) {
    null => null,
    // Among friends sharing a device, it's by name: everyone is watching.
    final winner when winner == _viewer && !_passAndPlay =>
      'You won the round!',
    final winner => '${_nameOf(winner)} won the round.',
  };

  /// Applies [message] from the player on another device at [seat]: a move
  /// on their turn, or their opening choice before play starts. A move the
  /// engine refuses goes back to them with the reason.
  void _onRemote(int seat, WireMessage message) {
    if (message is! MoveMessage) return;
    final player = _remote[seat]!;
    void refuse(String reason) => player.connection.send(Refused(reason));

    if (message case MoveOpenTunnellas(:final tunnellas)) {
      if (!_remoteChoosing.contains(seat)) return refuse('You have opened.');
      final refusal = _tryMove(
        () => _round.showOpeningTunnellas(seat, tunnellas),
      );
      if (refusal != null) return refuse(refusal);
      _remoteChoosing.remove(seat);
      _publish();
      final localChoosing = _people.any(
        (s) =>
            (s == _viewer ? state.openingChoice : _desks[s]?.openingChoice) !=
            null,
      );
      if (_remoteChoosing.isEmpty && !localChoosing) unawaited(_advance());
      return;
    }

    if (_round.isOver) return refuse('The round is over.');
    if (_round.currentSeat != seat) {
      return refuse('Wait for ${_nameOf(_round.currentSeat)} to play.');
    }
    final refusal = _tryMove(() {
      switch (message) {
        case MoveDraw(:final source):
          _round.draw(source);
        case MoveDiscard(:final card):
          _round.discard(card);
        case MoveShow(:final kind, :final sets, :final tipluPosition):
          switch (kind) {
            case ShowKind.doublees:
              _round.showDoublees(sets, tipluPosition: tipluPosition);
            case ShowKind.pureSets:
              _round.showPureSets(sets, tipluPosition: tipluPosition);
          }
        case MovePickTiplu(:final position):
          _round.pickTiplu(position);
        case MoveWin(:final card):
          _round.declareWin(card);
        case MoveOpenTunnellas():
          break;
      }
    });
    if (refusal != null) return refuse(refusal);
    _publish(notice: _winNotice());
    if (message is MoveDiscard) unawaited(_advance());
  }

  /// Listens to the player at [seat] on their device's current link.
  void _listenTo(int seat) {
    _listening[seat] = _remote[seat]!.connection.messages.listen(
      (message) => _onRemote(seat, message),
      onDone: () => _onRemoteGone(seat),
    );
  }

  /// The player at [seat] is back on [connection] after their link dropped:
  /// they take their seat again from the bot that stood in.
  void _onRejoin(int seat, Connection connection) {
    final player = _remote[seat];
    if (player == null || !ref.mounted) return;
    unawaited(_listening[seat]?.cancel());
    player.connection = connection;
    _listenTo(seat);
    _offline.remove(seat);
    _standIns.remove(seat);
    _publish(notice: '${_nameOf(seat)} is back.');
  }

  /// The bot that plays [seat]: one of the match's bots, or one standing in
  /// for a player whose link has dropped. `null` for a person who's there.
  BotPlayer? _botFor(int seat) =>
      _bots[seat] ??
      (_offline.contains(seat)
          ? _standIns.putIfAbsent(
              seat,
              () => BotPlayer(
                difficulty: BotDifficulty.medium,
                personality: BotPersonality.pick(1, _random).single,
                random: _random,
              ),
            )
          : null);

  /// The link to the player at [seat] has dropped: a bot plays for them
  /// from now on, making any opening choice they still owed and finishing
  /// their turn if it was theirs.
  void _onRemoteGone(int seat) {
    if (!ref.mounted || _offline.contains(seat)) return;
    _offline.add(seat);
    if (_remoteChoosing.remove(seat)) {
      final tunnellas = findTunnellas(_round.hands[seat].cards);
      _round.showOpeningTunnellas(
        seat,
        tunnellas.take(PlayerHand.maxOpeningTunnellas).toList(),
      );
    }
    _publish(
      notice:
          '${_nameOf(seat)} lost connection. A bot plays for them until '
          'they\'re back.',
    );
    final localChoosing = _people.any(
      (s) =>
          (s == _viewer ? state.openingChoice : _desks[s]?.openingChoice) !=
          null,
    );
    if (!_round.isOver && _remoteChoosing.isEmpty && !localChoosing) {
      unawaited(_advance());
    }
  }

  /// Sends every player on another device what they may now see.
  void _sendUpdates() {
    for (final MapEntry(key: seat, value: player) in _remote.entries) {
      player.connection.send(
        SeatUpdate(
          view: _viewFor(seat),
          handProgress: handProgress(
            _round.hands[seat],
            _round.jokersFor(seat),
            alterIsMaal: _round.config.alterIsMaal,
          ),
          winningCards: _winningCardsFor(seat),
          roundNumber: _roundNumber,
          seatNames: [for (var s = 0; s < _round.hands.length; s++) _nameOf(s)],
          roundScores: _match.rounds,
          totals: _match.totals,
          jokerPenalty: jokerPenaltyEnabled,
          mode: mode,
          choosingOpening: _remoteChoosing.contains(seat),
          match: _matchId,
          offline: [..._offline],
        ),
      );
    }
  }

  /// Plays any bots' turns, then turns the table to the person who plays
  /// next.
  Future<void> _advance() async {
    // With no bot to wait for, the table turns straight away.
    if (_botFor(_round.currentSeat) != null) await _playBots();
    if (!ref.mounted || _round.isOver) return;
    final next = _round.currentSeat;
    if (_people.contains(next) && next != _viewer) _switchTo(next);
  }

  /// Turns the table to [seat]'s view, keeping the current person's hand,
  /// groups and selection on their desk until it's their view again.
  void _switchTo(int seat) {
    _desks[_viewer] = _Desk(
      hand: state.hand,
      groups: state.groups,
      selected: state.selected,
      openingChoice: state.openingChoice,
    );
    _viewer = seat;
    final desk = _desks.remove(seat) ?? _Desk();
    state = state.copyWith(
      hand: desk.hand,
      groups: desk.groups,
      selected: desk.selected,
      openingChoice: () => desk.openingChoice,
      pickingTiplu: false,
      revealingJoker: false,
      // Covered until [seat]'s person has the device.
      passingTo: () => seat,
    );
    _publish();
  }

  /// [seats] in the order they play this round, from the first player.
  List<int> _inTurnOrder(Iterable<int> seats) {
    final count = _round.hands.length;
    return [
      for (var i = 0; i < count; i++)
        if (seats.contains((_firstSeat + i) % count)) (_firstSeat + i) % count,
    ];
  }

  /// Plays bot turns, with a thinking pause before each, until it's a
  /// person's turn or the round is over. Only one run happens at a
  /// time; calling again while bots are playing joins the current run.
  Future<void> _playBots() =>
      _botsPlaying ??= _runBots().whenComplete(() => _botsPlaying = null);

  Future<void> _runBots() async {
    while (!_round.isOver && _botFor(_round.currentSeat) != null) {
      await Future<void>.delayed(_thinkingTime());
      if (!ref.mounted) return;
      final seat = _round.currentSeat;
      // The player may have come back while the bot was thinking.
      final bot = _botFor(seat);
      if (bot == null) return;
      final turn = bot.takeTurn(_round);
      _publish(notice: turn.won ? '${_nameOf(seat)} won the round.' : null);
    }
  }

  void _publish({String? notice, Set<int> removed = const {}}) {
    // Score a finished round once, however it ended.
    if (_round.isOver && !_roundRecorded) {
      final score = _round.score();
      _match.addRound(score);
      // Coins are the device owner's, won against bots: each point is worth
      // the table's stake. A game among friends, on one device or several,
      // doesn't touch them.
      final playerData = ref.read(playerDataProvider.notifier);
      if (!_passAndPlay && _remote.isEmpty) {
        unawaited(playerData.addCoins(score.net[humanSeat] * (_stake ?? 1)));
      }
      // So are the stats, except when several people share the device, and
      // the round counts toward unlocking the next stake table.
      if (!_passAndPlay) {
        unawaited(
          playerData.recordGameResult(
            won: score.winner == humanSeat,
            points: score.net[humanSeat],
            stake: _remote.isEmpty ? _stake : null,
          ),
        );
      }
      _roundRecorded = true;
    }

    final hand = _heldFrom([
      for (final handCard in state.hand)
        if (!removed.contains(handCard.id)) handCard,
    ]);
    final ids = {for (final c in hand) c.id};
    final groups = [
      for (final group in state.groups) group.where(ids.contains).toList(),
    ].where((group) => group.isNotEmpty).toList();
    state = state.copyWith(
      view: _snapshot(),
      hand: hand,
      selected: state.selected.where(ids.contains).toSet(),
      groups: groups,
      winningDiscards: _winningDiscards(hand),
      roundScores: List.unmodifiable(_match.rounds),
      totals: List.unmodifiable(_match.totals),
      handProgress: _handProgress(),
      notice: notice,
      offlineSeats: {..._offline},
    );
    _sendUpdates();
  }

  /// Ids of the cards in [hand] that would leave a winning hand if
  /// discarded now. Empty unless it's the viewer's turn, they've drawn and
  /// they've seen the joker.
  Set<int> _winningDiscards(List<HandCard> hand) {
    final winning = _winningCardsFor(_viewer);
    return {
      for (final handCard in hand)
        if (winning.contains(handCard.card)) handCard.id,
    };
  }

  /// The cards [seat] holds that would leave a winning hand if discarded
  /// now. Empty unless it's their turn, they've drawn and they've seen the
  /// joker.
  List<PlayingCard> _winningCardsFor(int seat) {
    final player = _round.hands[seat];
    final jokers = _round.jokersFor(seat);
    final route = player.showKind;
    if (_round.isOver ||
        _round.currentSeat != seat ||
        !player.hasDrawn ||
        jokers == null ||
        route == null) {
      return [];
    }
    bool isWinningHand(List<PlayingCard> cards) => switch (route) {
      ShowKind.pureSets => canSplitIntoSets(cards, jokers),
      ShowKind.doublees => containsDoubleeWithJokers(cards, jokers),
    };

    final held = player.cards;
    return [
      for (final (i, candidate) in held.indexed)
        if (!held.take(i).contains(candidate) &&
            isWinningHand([...held.take(i), ...held.skip(i + 1)]))
          candidate,
    ];
  }

  /// [shown] brought in line with the cards the viewer holds.
  List<HandCard> _heldFrom(List<HandCard> shown) =>
      reconcile(_round.hands[_viewer].cards, shown);

  HandProgress _handProgress() => handProgress(
    _round.hands[_viewer],
    _round.jokersFor(_viewer),
    alterIsMaal: _round.config.alterIsMaal,
  );

  TableView _snapshot() => _viewFor(_viewer);

  TableView _viewFor(int seat) => TableView.fromRound(
    _round,
    humanSeat: seat,
    nameOf: _nameOf,
    avatarOf: (seat) => _bots[seat]?.personality.avatarColor,
  );

  String _nameOf(int seat) => switch ((_bots[seat], _remote[seat])) {
    (final bot?, _) => bot.personality.name,
    (_, final remote?) => remote.name,
    _ when _peopleNames.isEmpty => 'You',
    _ => _peopleNames[seat],
  };
}

/// One person's private table while someone else's view is showing: their
/// hand in the order they arranged it, their groups and selection, and the
/// opening tunnellas they still have to choose from.
class _Desk {
  _Desk({
    this.hand = const [],
    this.groups = const [],
    this.selected = const {},
    this.openingChoice,
  });

  final List<HandCard> hand;
  final List<List<int>> groups;
  final Set<int> selected;
  final List<List<PlayingCard>>? openingChoice;
}

/// The engine's reason for refusing a move, naming the card when there is
/// one.
String _explain(ArgumentError e) => switch (e.invalidValue) {
  PlayingCard card => '$card ${e.message}',
  _ => '${e.message}',
};
