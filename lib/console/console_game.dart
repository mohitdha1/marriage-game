import 'dart:math';

import '../engine/card.dart';
import '../engine/game_config.dart';
import '../engine/melds.dart';
import '../engine/player_hand.dart';
import '../engine/round.dart';
import '../engine/scoring.dart';
import '../bots/bot_personality.dart';
import '../bots/bot_player.dart';

/// Reads one line of input, or returns `null` when input has ended.
typedef ReadLine = String? Function();

/// Writes one line of output.
typedef WriteLine = void Function(String line);

/// Starts a round with play beginning at [firstSeat].
typedef RoundDealer = Round Function(int firstSeat);

/// A text version of the game: one human at [humanSeat] against
/// [BotPlayer]s at [difficulty], or bots only when [humanSeat] is `null`.
/// Each bot gets its own personality and name.
///
/// All the rules come from the engine. This class only turns typed commands
/// into engine calls and engine state into text, and reports the engine's
/// errors back to the player. Input and output go through [readLine] and
/// [writeLine] so tests can script a game.
class ConsoleGame {
  ConsoleGame({
    required this.config,
    required Random random,
    required this.readLine,
    required this.writeLine,
    this.humanSeat = 0,
    this.maxTurns = 500,
    this.difficulty = BotDifficulty.medium,
    RoundDealer? dealRound,
  }) : _bots = _seatBots(config, humanSeat, difficulty, random),
       _dealRound =
           dealRound ??
           ((firstSeat) => Round.deal(
             config: config,
             random: random,
             firstSeat: firstSeat,
           )),
       match = MatchScore(config.playerCount);

  final GameConfig config;
  final ReadLine readLine;
  final WriteLine writeLine;

  /// The human's seat, or `null` for a bots-only game.
  final int? humanSeat;

  /// After this many turns without a winner, the round ends and scores
  /// nothing.
  final int maxTurns;

  /// How well the bots play.
  final BotDifficulty difficulty;

  final MatchScore match;

  /// The bot playing each seat that isn't the human's.
  final Map<int, BotPlayer> _bots;
  final RoundDealer _dealRound;

  bool get _botsOnly => humanSeat == null;

  String nameOf(int seat) =>
      seat == humanSeat ? 'You' : _bots[seat]!.personality.name;

  static Map<int, BotPlayer> _seatBots(
    GameConfig config,
    int? humanSeat,
    BotDifficulty difficulty,
    Random random,
  ) {
    final seats = [
      for (var seat = 0; seat < config.playerCount; seat++)
        if (seat != humanSeat) seat,
    ];
    final personalities = BotPersonality.pick(seats.length, random, difficulty);
    return {
      for (var i = 0; i < seats.length; i++)
        seats[i]: BotPlayer(
          difficulty: difficulty,
          personality: personalities[i],
          random: random,
        ),
    };
  }

  /// Plays rounds, rotating who goes first. A bots-only game plays
  /// [rounds] rounds; with a human, there's no limit — they're asked after
  /// each round whether to carry on.
  void playMatch({int rounds = 1}) {
    var played = 0;
    try {
      while (true) {
        _playRound(number: played + 1, firstSeat: played % config.playerCount);
        played++;
        if (_botsOnly) {
          if (played >= rounds) break;
        } else {
          writeLine('Play another round? (y/n)');
          if (readLine()?.trim().toLowerCase() != 'y') break;
        }
      }
    } on _QuitGame {
      writeLine('Game stopped.');
    }
    _printMatchTotals();
  }

  void _playRound({required int number, required int firstSeat}) {
    final round = _dealRound(firstSeat);
    writeLine('');
    writeLine('=== Round $number ===');
    writeLine(
      '${config.playerCount} players. ${nameOf(firstSeat)} '
      '${firstSeat == humanSeat ? 'play' : 'plays'} first. '
      'The discard pile starts with ${round.topDiscard}.',
    );

    for (var seat = 0; seat < config.playerCount; seat++) {
      final tunnellas = seat == humanSeat
          ? _humanOpeningTunnellas(round.hands[seat])
          : _bots[seat]!.openingTunnellas(round.hands[seat].cards);
      round.showOpeningTunnellas(seat, tunnellas);
      if (tunnellas.isNotEmpty) {
        writeLine('${nameOf(seat)} opened with ${_sets(tunnellas)}.');
      }
    }

    var turns = 0;
    while (!round.isOver) {
      if (turns >= maxTurns) {
        writeLine(
          'No winner after $maxTurns turns — this round scores '
          'nothing.',
        );
        return;
      }
      if (round.currentSeat == humanSeat) {
        _humanTurn(round);
      } else {
        _botTurn(round);
      }
      turns++;
    }

    final score = round.score();
    match.addRound(score);
    _printRoundScore(round, score);
  }

  // --- Bots -----------------------------------------------------------

  void _botTurn(Round round) {
    final name = nameOf(round.currentSeat);
    final turn = _bots[round.currentSeat]!.takeTurn(round);

    final parts = [
      ?switch (turn.drewFrom) {
        DrawSource.stock => '$name draws from the stock',
        DrawSource.discardPile =>
          '$name takes ${turn.drawn} from the discard pile',
        null => null,
      },
      if (turn.shown.isNotEmpty)
        'shows ${_sets(turn.shown)} and sees the joker'
            '${turn.pickedTiplu ? ' (picking the tiplu from the stock)' : ''}',
      turn.won
          ? 'and WINS, discarding ${turn.discarded}!'
          : 'and discards ${turn.discarded}.',
    ];
    writeLine(parts.join(', '));
  }

  // --- The human ------------------------------------------------------

  List<List<PlayingCard>> _humanOpeningTunnellas(PlayerHand hand) {
    final tunnellas = findTunnellas(hand.cards);
    if (tunnellas.length <= PlayerHand.maxOpeningTunnellas) return tunnellas;

    writeLine(
      'You were dealt ${tunnellas.length} tunnellas but can only '
      'show ${PlayerHand.maxOpeningTunnellas}. Pick which:',
    );
    for (var i = 0; i < tunnellas.length; i++) {
      writeLine('  ${i + 1}: ${_set(tunnellas[i])}');
    }
    while (true) {
      writeLine('Enter 3 numbers, e.g. "1 2 3":');
      final picks = _parseNumbers(_read());
      if (picks != null &&
          picks.length == PlayerHand.maxOpeningTunnellas &&
          picks.toSet().length == picks.length &&
          picks.every((n) => n >= 1 && n <= tunnellas.length)) {
        return [for (final n in picks) tunnellas[n - 1]];
      }
      writeLine('Please pick 3 different numbers from the list.');
    }
  }

  void _humanTurn(Round round) {
    final seat = round.currentSeat;
    writeLine('');
    writeLine('--- Your turn ---');
    _printTable(round, seat);
    _printHand(round, seat);
    writeLine('Type "help" for commands.');

    while (round.currentSeat == seat && !round.isOver) {
      final line = _read().trim();
      final space = line.indexOf(' ');
      final command = (space < 0 ? line : line.substring(0, space))
          .toLowerCase();
      final args = space < 0 ? '' : line.substring(space + 1);

      try {
        switch (command) {
          case 'help' || '?':
            _printHelp();
          case 'hand' || 'h':
            _printTable(round, seat);
            _printHand(round, seat);
          case 'draw' || 'd':
            writeLine('You drew ${round.draw(DrawSource.stock)}.');
            _printHand(round, seat);
          case 'take' || 't':
            writeLine(
              'You took ${round.draw(DrawSource.discardPile)} from the '
              'discard pile.',
            );
            _printHand(round, seat);
          case 'show':
            _humanShow(round, seat, args, doublees: false);
          case 'doublees':
            _humanShow(round, seat, args, doublees: true);
          case 'discard' || 'x':
            final card = _cardAt(round, seat, args);
            final sawJoker = round.hands[seat].hasSeenJoker;
            round.discard(card);
            if (round.isOver) {
              writeLine('You discard $card and WIN the round!');
            } else {
              writeLine('You discarded $card.');
              _pickTiplu(round, first: true);
              if (!sawJoker && round.hands[seat].hasSeenJoker) {
                writeLine('You see the joker.');
                _printJoker(round, seat);
              }
            }
          case 'win':
            final card = _cardAt(round, seat, args);
            round.declareWin(card);
            writeLine('You discard $card and WIN the round!');
          case 'quit' || 'q':
            throw _QuitGame();
          default:
            writeLine('Unknown command "$command". Type "help".');
        }
      } on ArgumentError catch (e) {
        writeLine('Not allowed: ${_explain(e)}');
      } on StateError catch (e) {
        writeLine('Not allowed: ${e.message}');
      } on FormatException catch (e) {
        writeLine(e.message);
      }
    }
  }

  void _humanShow(
    Round round,
    int seat,
    String args, {
    required bool doublees,
  }) {
    final hand = _sortedHand(round, seat);
    final sets = _parseSets(args, hand);

    // Only an early show, before the first draw, picks the tiplu with the
    // show; after drawing, the first to show picks it after the discard.
    int? tipluPosition;
    if (!round.isJokerChosen && !round.hands[seat].hasDrawn) {
      writeLine(
        'You are the first to show, so you pick the tiplu. Choose a '
        'stock position from 1 (top) to ${round.stockCount}:',
      );
      final picked = _parseNumbers(_read());
      if (picked == null || picked.length != 1) {
        throw const FormatException('Show cancelled: enter one number.');
      }
      tipluPosition = picked.single - 1;
    }

    if (doublees) {
      round.showDoublees(sets, tipluPosition: tipluPosition);
    } else {
      round.showPureSets(sets, tipluPosition: tipluPosition);
    }
    _pickTiplu(round, first: false);
    if (round.hands[seat].hasSeenJoker) {
      writeLine('You showed ${_sets(sets)} and saw the joker.');
      _printJoker(round, seat);
    } else {
      writeLine(
        'You showed ${_sets(sets)}. You see the joker after your discard, '
        'and can win from your next turn.',
      );
    }
    _printHand(round, seat);
  }

  /// Asks for the tiplu for as long as the round needs one picked: [first]
  /// when the player is the first to show and has just discarded, and
  /// again after each pick that was a printed joker.
  void _pickTiplu(Round round, {required bool first}) {
    var again = !first;
    while (round.needsTipluPick) {
      writeLine(
        again
            ? 'That card can\'t be the joker, so it\'s kept aside as your '
                  'maal. Pick again, from 1 (top) to ${round.stockCount}:'
            : 'You were the first to show, so you pick the tiplu. Choose a '
                  'stock position from 1 (top) to ${round.stockCount}:',
      );
      final picked = _parseNumbers(_read());
      if (picked != null && picked.length == 1) {
        try {
          round.pickTiplu(picked.single - 1);
          again = true;
        } on ArgumentError catch (e) {
          writeLine('${e.message}');
        }
      }
    }
  }

  /// Turns "1 2 3, 4 5 6" into sets of cards from the numbered [hand].
  /// Each number picks one card, so a card can't be used twice.
  List<List<PlayingCard>> _parseSets(String args, List<PlayingCard> hand) {
    final groups = args
        .split(',')
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty);
    final used = <int>{};
    final sets = <List<PlayingCard>>[];
    for (final group in groups) {
      final numbers = _parseNumbers(group);
      if (numbers == null) {
        throw FormatException('Could not read "$group" as card numbers.');
      }
      final set = <PlayingCard>[];
      for (final n in numbers) {
        if (n < 1 || n > hand.length) {
          throw FormatException('There is no card $n in your hand.');
        }
        if (!used.add(n)) {
          throw FormatException('Card $n is used more than once.');
        }
        set.add(hand[n - 1]);
      }
      sets.add(set);
    }
    return sets;
  }

  PlayingCard _cardAt(Round round, int seat, String args) {
    final hand = _sortedHand(round, seat);
    final numbers = _parseNumbers(args);
    if (numbers == null || numbers.length != 1) {
      throw const FormatException('Give one card number, e.g. "discard 5".');
    }
    final n = numbers.single;
    if (n < 1 || n > hand.length) {
      throw FormatException('There is no card $n in your hand.');
    }
    return hand[n - 1];
  }

  String _read() {
    final line = readLine();
    if (line == null) throw _QuitGame();
    return line;
  }

  // --- Printing -------------------------------------------------------

  void _printHelp() {
    for (final line in [
      'Commands (card numbers are from your hand listing):',
      '  draw | d              draw from the stock',
      '  take | t              take the top card of the discard pile',
      '  show 1 2 3, 4 5 6 …   show pure sets to see the joker',
      '  doublees 1 2, 3 4 …   show 7 doublees to see the joker',
      '  discard 5 | x 5       discard a card and end your turn',
      '  win 5                 discard a card and finish the round',
      '  hand | h              show the table and your hand again',
      '  quit | q              stop the game',
    ]) {
      writeLine(line);
    }
  }

  void _printTable(Round round, int seat) {
    writeLine(
      'Stock: ${round.stockCount} cards. Discard pile: '
      '${round.topDiscard ?? 'empty'}.',
    );
    _printJoker(round, seat);
    for (var other = 0; other < config.playerCount; other++) {
      final hand = round.hands[other];
      final laidDown = [...hand.openingTunnellas, ...hand.shownSets];
      if (laidDown.isNotEmpty) {
        writeLine('${nameOf(other)} laid down: ${_sets(laidDown)}');
      }
    }
  }

  void _printJoker(Round round, int seat) {
    final jokers = round.jokersFor(seat);
    if (jokers != null) {
      writeLine(
        'Joker: tiplu ${jokers.tiplu}, jhiplu ${jokers.jhiplu}, poplu '
        '${jokers.poplu}, alter ${jokers.alter} (all ${jokers.tiplu.rank!.label}s '
        'are wild).',
      );
    } else if (round.isJokerChosen) {
      writeLine('Joker: picked, but you have not seen it yet.');
    } else {
      writeLine('Joker: not picked yet.');
    }
  }

  void _printHand(Round round, int seat) {
    final hand = _sortedHand(round, seat);
    writeLine('Your hand:');
    writeLine(
      [for (var i = 0; i < hand.length; i++) '${i + 1}:${hand[i]}'].join('  '),
    );
  }

  void _printRoundScore(Round round, RoundScore score) {
    writeLine('');
    writeLine(
      '${nameOf(score.winner)} won the round. The tiplu was '
      '${round.jokersFor(score.winner)!.tiplu}.',
    );
    for (var seat = 0; seat < config.playerCount; seat++) {
      final penalty = score.penalties[seat] > 0
          ? ', joker-discard penalty ${score.penalties[seat]}'
          : '';
      writeLine(
        '  ${nameOf(seat).padRight(6)} maal ${score.maal[seat].total}'
        '$penalty, round ${_signed(score.net[seat])}',
      );
    }
  }

  void _printMatchTotals() {
    if (match.rounds.isEmpty) return;
    writeLine('');
    writeLine(
      'Match totals after ${match.rounds.length} '
      '${match.rounds.length == 1 ? 'round' : 'rounds'}:',
    );
    for (var seat = 0; seat < config.playerCount; seat++) {
      writeLine('  ${nameOf(seat).padRight(6)} ${_signed(match.totals[seat])}');
    }
    final leaders = match.leaders.map(nameOf).join(' and ');
    writeLine('Leading: $leaders.');
  }

  List<PlayingCard> _sortedHand(Round round, int seat) =>
      sortForDisplay(round.hands[seat].cards);
}

/// Cards sorted by suit, then rank, with printed jokers last — the order the
/// console numbers them in.
List<PlayingCard> sortForDisplay(List<PlayingCard> cards) =>
    [...cards]..sort((a, b) => cardIndex(a).compareTo(cardIndex(b)));

String _set(List<PlayingCard> set) => '[${set.join(' ')}]';

String _sets(List<List<PlayingCard>> sets) => sets.map(_set).join(' ');

String _signed(int n) => n > 0 ? '+$n' : '$n';

/// Parses space-separated whole numbers, or returns `null` if any part isn't
/// one (or there are none).
List<int>? _parseNumbers(String text) {
  final parts = text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.isEmpty || numbers.contains(null)) return null;
  return numbers.cast<int>();
}

/// The engine's reason, naming the card when there is one.
String _explain(ArgumentError e) => switch (e.invalidValue) {
  PlayingCard card => '$card ${e.message}',
  _ => '${e.message}',
};

/// Thrown to unwind out of a match when the human quits or input ends.
class _QuitGame implements Exception {}
