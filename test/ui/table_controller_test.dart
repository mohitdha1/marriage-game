import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/bots/bot_personality.dart';
import 'package:marriage_game/bots/bot_player.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/data/player_data.dart';
import 'package:marriage_game/data/stake_tables.dart';
import 'package:marriage_game/ui/home/player_data_provider.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_notifier.dart';
import 'package:marriage_game/ui/state/table_state.dart';

const c = PlayingCard.new;

List<PlayingCard> run(Suit suit, List<Rank> ranks) => [
  for (final rank in ranks) c(suit, rank),
];

List<PlayingCard> tunnellaOf(PlayingCard card) => [card, card, card];

final heartsRun = run(Suit.hearts, [Rank.three, Rank.four, Rank.five]);
final spadesRun = run(Suit.spades, [Rank.two, Rank.three, Rank.four]);
final clubsRun = run(Suit.clubs, [Rank.nine, Rank.ten, Rank.jack]);
final twoOfDiamonds = c(Suit.diamonds, Rank.two);
final queenOfDiamonds = c(Suit.diamonds, Rank.queen);
final kingOfClubs = c(Suit.clubs, Rank.king);

/// The human player's usual hand: 3 pure runs and a few loose cards.
final yourCards = [
  ...heartsRun,
  ...spadesRun,
  ...clubsRun,
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  twoOfDiamonds,
];

/// Three runs, then K♠ K♦ 7♣ 10♦ J♦ 8♥ 2♦: once 7♥ is the tiplu and Q♦
/// drawn, everything but 2♦ makes sets.
final winnableCards = [
  ...yourCards.take(9),
  c(Suit.spades, Rank.king),
  c(Suit.diamonds, Rank.king),
  c(Suit.clubs, Rank.seven),
  c(Suit.diamonds, Rank.ten),
  c(Suit.diamonds, Rank.jack),
  c(Suit.hearts, Rank.eight),
  twoOfDiamonds,
];

/// A bot hand with nothing to show, so the bot only draws and discards.
final idleBotCards = run(Suit.spades, [Rank.six, Rank.eight, Rank.queen]);

/// A container whose round deals [yourHand] to the human player (seat 0)
/// and [botHand] to one bot, with the stock's top card last.
ProviderContainer tableWith({
  List<PlayingCard>? yourHand,
  List<PlayingCard>? botHand,
  List<PlayingCard>? stock,
  List<PlayingCard>? discardPile,
  int? firstSeat,
  Duration thinkingTime = Duration.zero,
  GameConfig? config,
  List<String>? people,
  MatchSetup? setup,
}) {
  final container = ProviderContainer(
    overrides: [
      randomProvider.overrideWithValue(Random(0)),
      botThinkingTimeProvider.overrideWithValue(() => thinkingTime),
      roundFactoryProvider.overrideWithValue(
        (seat) => Round.fromCards(
          config: config ?? GameConfig(playerCount: 2),
          random: Random(0),
          hands: [yourHand ?? yourCards, botHand ?? idleBotCards],
          stock:
              stock ??
              [
                c(Suit.clubs, Rank.five),
                c(Suit.hearts, Rank.seven),
                c(Suit.clubs, Rank.two),
                queenOfDiamonds,
              ],
          discardPile: discardPile ?? [kingOfClubs],
          firstSeat: firstSeat ?? seat,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (people != null) {
    container
        .read(matchSetupProvider.notifier)
        .choose(MatchSetup.passAndPlay(people));
  }
  if (setup != null) container.read(matchSetupProvider.notifier).choose(setup);
  return container;
}

extension on ProviderContainer {
  TableState get table => read(tableProvider);
  TableNotifier get controller => read(tableProvider.notifier);

  /// Selects the hand cards equal to [cards] (one copy each) and groups
  /// them.
  void group(List<PlayingCard> cards) {
    final used = <int>{};
    for (final card in cards) {
      final id = table.hand
          .firstWhere((c) => c.card == card && !used.contains(c.id))
          .id;
      used.add(id);
      controller.toggleSelected(id);
    }
    controller.groupSelected();
  }

  /// The id of the first card in hand equal to [card].
  int idOf(PlayingCard card) =>
      table.hand.firstWhere((handCard) => handCard.card == card).id;

  /// Plays the human player's first turn and the bot's, then draws again:
  /// draws Q♦, shows the three runs, discards 2♦ and picks 7♥ (second from
  /// the top once Q♦ is drawn) as the tiplu. A show can't win that turn, so
  /// this is the earliest a win can come.
  Future<void> showThenDrawAgain() async {
    controller.draw(DrawSource.stock);
    group(heartsRun);
    group(spadesRun);
    group(clubsRun);
    controller.showGroups();
    await controller.discard(idOf(twoOfDiamonds));
    controller
      ..pickTiplu(1)
      ..dismissReveal();
    await controller.botsSettled;
    controller.draw(DrawSource.stock);
  }
}

final kingOfSpades = c(Suit.spades, Rank.king);

/// A table where the bot wins on its second turn. The bot holds 3 runs and
/// a trial of queens. You take K♣ and discard 3♥; the bot draws 10♥, shows,
/// throws 10♥ and picks the tiplu. You draw and discard what you drew; the
/// bot then draws and wins by throwing whatever it drew.
Future<ProviderContainer> botWinsOnItsSecondTurn({MatchSetup? setup}) async {
  final container = tableWith(
    setup: setup,
    botHand: [
      ...run(Suit.spades, [Rank.jack, Rank.queen, Rank.king]),
      ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
      ...run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]),
      c(Suit.clubs, Rank.queen),
      queenOfDiamonds,
      c(Suit.hearts, Rank.queen),
    ],
    stock: [
      c(Suit.clubs, Rank.two),
      c(Suit.spades, Rank.nine),
      c(Suit.hearts, Rank.four),
      c(Suit.hearts, Rank.ten),
    ],
  )..controller.tapDiscardPile();
  await container.controller.discard(
    container.idOf(c(Suit.hearts, Rank.three)),
  );
  container.controller.draw(DrawSource.stock);
  await container.controller.discard(container.table.hand.last.id);
  return container;
}

/// The player's coins and stats once every change asked for has been saved.
Future<PlayerData> settledPlayerData(ProviderContainer container) async {
  await Future<void>.delayed(Duration.zero);
  return container.read(playerDataProvider.future);
}

void main() {
  group('Dealing', () {
    test('the hand is dealt sorted by suit, then rank, each card with its '
        'own id', () {
      final table = tableWith(
        yourHand: [
          c(Suit.diamonds, Rank.two),
          c(Suit.hearts, Rank.king),
          c(Suit.spades, Rank.nine),
          c(Suit.clubs, Rank.ace),
          c(Suit.hearts, Rank.three),
          c(Suit.spades, Rank.four),
        ],
      ).table;

      expect(table.hand.map((c) => c.card), [
        c(Suit.spades, Rank.four),
        c(Suit.spades, Rank.nine),
        c(Suit.hearts, Rank.three),
        c(Suit.hearts, Rank.king),
        c(Suit.clubs, Rank.ace),
        c(Suit.diamonds, Rank.two),
      ]);
      expect(table.hand.map((c) => c.id).toSet(), hasLength(6));
      expect(table.view.isYourTurn, isTrue);
    });

    test('a drawn card joins the sorted hand at the right-hand end', () {
      final container = tableWith(
        yourHand: [c(Suit.hearts, Rank.king), c(Suit.spades, Rank.nine)],
      );
      container.controller.draw(DrawSource.stock);

      final hand = container.table.hand.map((c) => c.card).toList();
      expect(hand.take(2), [
        c(Suit.spades, Rank.nine),
        c(Suit.hearts, Rank.king),
      ]);
      expect(hand, hasLength(3));
    });

    test('every card in the dealt hand has its own id', () {
      final table = tableWith().table;

      expect(table.hand.map((c) => c.card), unorderedEquals(yourCards));
      expect(table.hand.map((c) => c.id).toSet(), hasLength(yourCards.length));
      expect(table.view.isYourTurn, isTrue);
    });

    test('dealt tunnellas are laid down automatically', () {
      final kings = tunnellaOf(c(Suit.spades, Rank.king));
      final table = tableWith(yourHand: [...heartsRun, ...kings]).table;

      expect(table.hand.map((c) => c.card), heartsRun);
      expect(table.openingChoice, isNull);
    });
  });

  group('Opening with more than 3 tunnellas', () {
    final fourTunnellas = [
      for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
        ...tunnellaOf(c(Suit.clubs, rank)),
    ];

    test('the player is asked to choose, and play waits', () {
      final container = tableWith(yourHand: fourTunnellas);

      expect(container.table.openingChoice, hasLength(4));
      expect(container.table.hand, hasLength(12));

      container.controller.draw(DrawSource.stock);
      expect(
        container.table.notice,
        'Every player must make their opening show first',
      );
    });

    test('an invalid choice is refused', () {
      final container = tableWith(yourHand: fourTunnellas);

      container.controller.chooseOpeningTunnellas([0, 0, 1]);

      expect(container.table.notice, 'Choose 3 different tunnellas.');
      expect(container.table.openingChoice, isNotNull);
    });

    test('choosing 3 lays them down and play starts', () {
      final container = tableWith(yourHand: fourTunnellas);

      container.controller.chooseOpeningTunnellas([0, 1, 3]);

      expect(container.table.openingChoice, isNull);
      expect(
        container.table.hand.map((c) => c.card),
        tunnellaOf(c(Suit.clubs, Rank.nine)),
      );
      container.controller.draw(DrawSource.stock);
      expect(container.table.view.youHaveDrawn, isTrue);
    });
  });

  group('Selecting and sorting', () {
    test('tapping a card selects it, tapping again deselects it', () {
      final container = tableWith();
      final id = container.idOf(twoOfDiamonds);

      container.controller.toggleSelected(id);
      expect(container.table.selected, {id});

      container.controller.toggleSelected(id);
      expect(container.table.selected, isEmpty);
    });

    test('identical cards are selected separately', () {
      final container = tableWith(yourHand: [...yourCards, twoOfDiamonds]);
      final twos = container.table.hand
          .where((c) => c.card == twoOfDiamonds)
          .map((c) => c.id)
          .toList();

      container.controller.toggleSelected(twos.first);

      expect(container.table.selected, {twos.first});
    });

    test('a card can be moved to any position, and stays there', () {
      final container = tableWith();
      final ids = container.table.hand.map((c) => c.id).toList();

      container.controller.moveCard(ids.last, 0);
      expect(container.table.hand.first.id, ids.last);

      container.controller.moveCard(ids.last, 3);
      expect(container.table.hand[3].id, ids.last);
      expect(container.table.hand.map((c) => c.id).toSet(), ids.toSet());

      // Drawing adds at the end without disturbing the arrangement.
      final arranged = container.table.hand;
      container.controller.draw(DrawSource.stock);
      expect(container.table.hand.take(arranged.length), arranged);
    });

    test('moving to a position past the end puts the card last', () {
      final container = tableWith();
      final first = container.table.hand.first.id;

      container.controller.moveCard(first, 99);

      expect(container.table.hand.last.id, first);
    });

    test('Sort orders the hand by suit (♠ ♥ ♣ ♦), then rank, keeping ids', () {
      final container = tableWith();
      final idsBefore = {for (final c in container.table.hand) c.id: c.card};

      container.controller.sortHand();

      final sorted = container.table.hand;
      for (var i = 1; i < sorted.length; i++) {
        final a = sorted[i - 1].card;
        final b = sorted[i].card;
        final order = TableNotifier.sortedSuits;
        expect(
          order.indexOf(a.suit!) < order.indexOf(b.suit!) ||
              (a.suit == b.suit && a.rank!.order <= b.rank!.order),
          isTrue,
          reason: '$a should come before $b',
        );
      }
      for (final handCard in sorted) {
        expect(idsBefore[handCard.id], handCard.card);
      }
    });

    test('Sort keeps grouped sets together at the front', () {
      final container = tableWith()
        ..group(clubsRun)
        ..group(heartsRun);

      container.controller.sortHand();

      final cards = container.table.hand.map((c) => c.card).toList();
      expect(cards.take(6), [...clubsRun, ...heartsRun]);
      expect(container.table.groups, hasLength(2));
      // The rest is sorted ♠ first.
      expect(cards[6].suit, Suit.spades);
    });
  });

  group('Drawing', () {
    test('drawing from the stock adds the card at the right-hand end', () {
      final container = tableWith();

      container.controller.draw(DrawSource.stock);

      expect(container.table.hand.last.card, queenOfDiamonds);
      expect(container.table.hand, hasLength(yourCards.length + 1));
      expect(container.table.view.youHaveDrawn, isTrue);
    });

    test('a second draw is refused with the engine\'s reason', () {
      final container = tableWith();

      container.controller
        ..draw(DrawSource.stock)
        ..draw(DrawSource.stock);

      expect(container.table.notice, 'Already drew this turn; discard first');
      expect(container.table.hand, hasLength(yourCards.length + 1));
    });

    test('tapping the discard pile before drawing takes its top card', () {
      final container = tableWith();

      container.controller.tapDiscardPile();

      expect(container.table.hand.last.card, kingOfClubs);
      expect(container.table.view.topDiscard, isNull);
    });

    test('a sorted hand stays in place when a card is drawn', () {
      final container = tableWith()..controller.sortHand();
      final sorted = container.table.hand;

      container.controller.draw(DrawSource.stock);

      expect(container.table.hand.take(sorted.length), sorted);
    });
  });

  group('Discarding', () {
    test(
      'discarding ends the turn; the bot plays and it is your turn again',
      () async {
        final container = tableWith()..controller.draw(DrawSource.stock);

        await container.controller.discard(container.idOf(twoOfDiamonds));

        final table = container.table;
        expect(table.hand.map((c) => c.card), isNot(contains(twoOfDiamonds)));
        expect(table.view.isYourTurn, isTrue);
        expect(table.view.youHaveDrawn, isFalse);
        expect(table.view.stockCount, 2, reason: 'you and the bot each drew');
      },
    );

    test('tapping the pile discards the selected card', () {
      final container = tableWith()..controller.draw(DrawSource.stock);
      container.controller
        ..toggleSelected(container.idOf(twoOfDiamonds))
        ..tapDiscardPile();

      expect(
        container.table.hand.map((c) => c.card),
        isNot(contains(twoOfDiamonds)),
      );
      expect(container.table.selected, isEmpty);
    });

    test('tapping the pile with nothing selected explains what to do', () {
      final container = tableWith()..controller.draw(DrawSource.stock);

      container.controller.tapDiscardPile();

      expect(
        container.table.notice,
        'Select one card, then tap the discard pile.',
      );
    });

    test('a card just taken from the discard pile cannot be discarded', () {
      final container = tableWith()..controller.tapDiscardPile();
      container.controller.discard(container.idOf(kingOfClubs));

      expect(
        container.table.notice,
        'K♣ was just taken from the discard pile and must be kept this turn',
      );
      expect(container.table.view.isYourTurn, isTrue);
    });

    test('discarding one of two identical cards removes just that one', () {
      final container = tableWith(yourHand: [...yourCards, twoOfDiamonds])
        ..controller.draw(DrawSource.stock);

      container.controller.discard(container.idOf(twoOfDiamonds));

      expect(
        container.table.hand.where((c) => c.card == twoOfDiamonds),
        hasLength(1),
      );
    });
  });

  group('Bots', () {
    test('a bot that wins ends the round, and the player is told', () async {
      final container = await botWinsOnItsSecondTurn();

      final table = container.table;
      final bot = table.view.opponents.single.name;
      expect(table.view.winner?.name, bot);
      expect(table.notice, '$bot won the round.');
      expect(table.view.isYourTurn, isFalse);
    });
  });

  group('Grouping', () {
    test('grouping needs at least 2 selected cards', () {
      final container = tableWith();
      container.controller
        ..toggleSelected(container.idOf(twoOfDiamonds))
        ..groupSelected();

      expect(container.table.notice, 'Select 2 or more cards to group.');
      expect(container.table.groups, isEmpty);
    });

    test('grouped cards move to the left, in the order they were grouped', () {
      final container = tableWith()
        ..group(clubsRun)
        ..group(heartsRun);

      expect(container.table.hand.take(6).map((c) => c.card), [
        ...clubsRun,
        ...heartsRun,
      ]);
      expect(container.table.groups, hasLength(2));
      expect(container.table.groupOf(container.idOf(clubsRun.first)), 0);
      expect(container.table.groupOf(container.idOf(heartsRun.first)), 1);
      expect(container.table.groupOf(container.idOf(twoOfDiamonds)), isNull);
      expect(container.table.selected, isEmpty);
    });

    test('grouping a card that is already grouped moves it', () {
      final container = tableWith()
        ..group(heartsRun)
        ..group([heartsRun.first, twoOfDiamonds]);

      expect(container.table.groups, hasLength(2));
      expect(container.table.groups.first, hasLength(2));
    });

    test('Ungroup clears every group', () {
      final container = tableWith()..group(heartsRun);

      container.controller.clearGroups();

      expect(container.table.groups, isEmpty);
    });
  });

  group('Showing', () {
    test('Show with nothing grouped explains what to do', () {
      final container = tableWith()..controller.showGroups();

      expect(container.table.notice, 'Group your sets first, then tap Show.');
    });

    test('the first to show picks the tiplu after their discard, then '
        'sees the joker', () async {
      final container = tableWith()
        ..controller.draw(DrawSource.stock) // Q♦; stock is now 2♣, 7♥, 5♣
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun);

      container.controller.showGroups();
      var table = container.table;
      expect(table.pickingTiplu, isFalse, reason: 'not until the discard');
      expect(table.view.youHaveShown, isTrue);
      expect(table.view.youHaveSeenJoker, isFalse);
      expect(table.revealingJoker, isFalse);
      expect(table.groups, isEmpty);
      expect(table.view.you.laidDown, [heartsRun, spadesRun, clubsRun]);
      expect(
        table.hand.map((c) => c.card),
        isNot(anyElement(isIn([...heartsRun, ...spadesRun, ...clubsRun]))),
      );

      await container.controller.discard(container.idOf(twoOfDiamonds));
      table = container.table;
      expect(table.pickingTiplu, isTrue);
      expect(table.view.isYourTurn, isTrue, reason: 'the pick comes first');

      container.controller.pickTiplu(1);
      table = container.table;
      expect(table.pickingTiplu, isFalse);
      expect(table.view.yourJokers?.tiplu, c(Suit.hearts, Rank.seven));
      expect(table.view.youHaveSeenJoker, isTrue);
      expect(table.revealingJoker, isTrue);

      container.controller.dismissReveal();
      expect(container.table.revealingJoker, isFalse);
      await container.controller.botsSettled;
    });

    test('a man card picked as the tiplu is kept aside, and the picker '
        'opens again with no way to cancel', () async {
      const man = PlayingCard.man();
      final container =
          tableWith(
              stock: [
                c(Suit.clubs, Rank.five),
                c(Suit.hearts, Rank.seven),
                man,
                queenOfDiamonds,
              ],
            )
            ..controller.draw(DrawSource.stock) // Q♦; stock is now man, 7♥, 5♣
            ..group(heartsRun)
            ..group(spadesRun)
            ..group(clubsRun)
            ..controller.showGroups();
      await container.controller.discard(container.idOf(twoOfDiamonds));
      container.controller.pickTiplu(0);

      var table = container.table;
      expect(table.view.youHaveSeenJoker, isTrue);
      expect(table.view.youMustPickTiplu, isTrue);
      expect(table.view.youPickTipluAgain, isTrue);
      expect(table.pickingTiplu, isTrue);
      expect(table.view.you.laidDown.last, [man]);

      container.controller.cancelTipluPick();
      expect(container.table.pickingTiplu, isTrue);

      container.controller.pickTiplu(0);

      table = container.table;
      expect(table.pickingTiplu, isFalse);
      expect(table.view.youMustPickTiplu, isFalse);
      expect(table.view.yourJokers?.tiplu, c(Suit.hearts, Rank.seven));
      expect(table.revealingJoker, isTrue);
      await container.controller.botsSettled;
    });

    test('a refused show keeps the groups and does not use up the tiplu', () {
      final container = tableWith()
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..group(spadesRun)
        ..controller.showGroups();

      expect(container.table.notice, 'must show exactly 3');
      expect(container.table.view.isJokerChosen, isFalse);
      expect(container.table.view.youHaveShown, isFalse);
      expect(container.table.groups, hasLength(2));
      expect(container.table.revealingJoker, isFalse);
    });

    test('an early show, before the first draw, picks the tiplu first and '
        'sees the joker straight away', () {
      final container = tableWith()
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun)
        ..controller.showGroups();
      expect(container.table.pickingTiplu, isTrue);

      // From the top: Q♦ (0), 2♣ (1), 7♥ (2).
      container.controller.pickTiplu(2);

      final table = container.table;
      expect(table.view.yourJokers?.tiplu, c(Suit.hearts, Rank.seven));
      expect(table.revealingJoker, isTrue);
      expect(table.view.youHaveDrawn, isFalse);
    });

    test('cancelling the tiplu pick of an early show shows nothing', () {
      final container = tableWith()
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun)
        ..controller.showGroups()
        ..controller.cancelTipluPick();

      expect(container.table.pickingTiplu, isFalse);
      expect(container.table.view.youHaveShown, isFalse);
    });

    test('once a bot has picked the tiplu, the discard after Show sees it, '
        'with no pick', () async {
      // The bot shows on its first turn, then picks the tiplu after its
      // discard.
      final container = tableWith(
        botHand: [
          ...run(Suit.spades, [Rank.jack, Rank.queen, Rank.king]),
          ...run(Suit.clubs, [Rank.four, Rank.five, Rank.six]),
          ...run(Suit.diamonds, [Rank.ace, Rank.two, Rank.three]),
          c(Suit.hearts, Rank.nine),
          c(Suit.clubs, Rank.queen),
        ],
      )..controller.draw(DrawSource.stock);
      await container.controller.discard(container.idOf(twoOfDiamonds));
      expect(container.table.view.isJokerChosen, isTrue);
      expect(container.table.view.yourJokers, isNull);
      expect(container.table.view.opponents.single.hasSeenJoker, isTrue);

      container
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun)
        ..controller.showGroups();
      expect(container.table.pickingTiplu, isFalse);
      expect(container.table.view.yourJokers, isNull);

      await container.controller.discard(
        container.idOf(c(Suit.spades, Rank.king)),
      );
      expect(container.table.pickingTiplu, isFalse);
      expect(container.table.view.yourJokers, isNotNull);
      expect(container.table.revealingJoker, isTrue);
    });

    test('7 grouped pairs are shown as doublees', () async {
      final pairs = [
        for (final rank in [
          Rank.two,
          Rank.three,
          Rank.four,
          Rank.five,
          Rank.nine,
          Rank.ten,
          Rank.jack,
        ])
          [c(Suit.clubs, rank), c(Suit.clubs, rank)],
      ];
      final container = tableWith(
        yourHand: [...pairs.expand((p) => p), c(Suit.spades, Rank.king)],
      )..controller.draw(DrawSource.stock);
      for (final pair in pairs) {
        container.group(pair);
      }

      container.controller.showGroups();
      expect(container.table.view.you.laidDown, pairs);
      await container.controller.discard(container.idOf(queenOfDiamonds));
      container.controller.pickTiplu(1);

      expect(container.table.view.youHaveSeenJoker, isTrue);
      await container.controller.botsSettled;
    });
  });

  group('Several people on one device', () {
    // Asha at seat 0 holds yourCards; Bina at seat 1 holds idleBotCards.
    /// Asha and Bina's table, with the device already in Asha's hands.
    ProviderContainer twoPeople({
      List<PlayingCard>? asha,
      List<PlayingCard>? bina,
    }) =>
        tableWith(people: ['Asha', 'Bina'], yourHand: asha, botHand: bina)
          ..controller.takeOver();

    test('everyone is called by name, and nobody is a bot', () {
      final container = twoPeople();

      expect(container.table.seatNames, ['Asha', 'Bina']);
      expect(container.table.view.you.name, 'Asha');
      expect(container.table.view.opponents.single.name, 'Bina');
    });

    test('the round opens covered until the first player has the device', () {
      final container = tableWith(people: ['Asha', 'Bina']);
      expect(container.table.passingTo, 0);

      container.controller.draw(DrawSource.stock);
      expect(container.table.notice, 'Pass the device to Asha first.');
      expect(container.table.view.youHaveDrawn, isFalse);

      container.controller.takeOver();
      expect(container.table.passingTo, isNull);
      container.controller.draw(DrawSource.stock);
      expect(container.table.view.youHaveDrawn, isTrue);
    });

    test('a game against bots is never covered', () {
      expect(tableWith().table.passingTo, isNull);
    });

    test(
      'after a turn, the table is covered and turns to the next person',
      () async {
        final container = twoPeople()..controller.draw(DrawSource.stock);

        await container.controller.discard(
          container.idOf(c(Suit.spades, Rank.king)),
        );
        expect(container.table.passingTo, 1);
        container.controller.takeOver();

        final view = container.table.view;
        expect(view.you.seat, 1);
        expect(view.isYourTurn, isTrue);
        expect(container.table.hand.map((h) => h.card), idleBotCards);
        expect(view.opponents.single.name, 'Asha');
      },
    );

    test(
      'each person\'s arrangement waits for them while others play',
      () async {
        final container = twoPeople()..controller.draw(DrawSource.stock);
        // Asha groups a run and puts K♦ first among the rest.
        container.group(heartsRun);
        container.controller.moveCard(
          container.idOf(c(Suit.diamonds, Rank.king)),
          3,
        );
        final ashas = container.table.hand.map((h) => h.card).toList();
        final ashasGroups = container.table.groups.length;

        await container.controller.discard(
          container.idOf(c(Suit.spades, Rank.king)),
        );
        // Bina plays her turn.
        container.controller
          ..takeOver()
          ..draw(DrawSource.stock);
        await container.controller.discard(container.table.hand.last.id);
        container.controller.takeOver();

        expect(container.table.view.you.seat, 0);
        expect(container.table.hand.map((h) => h.card), [
          ...ashas.where((card) => card != c(Suit.spades, Rank.king)),
        ]);
        expect(container.table.groups, hasLength(ashasGroups));
      },
    );

    test('a win is announced by name, and coins are left alone', () async {
      final container = twoPeople(
        asha: [
          ...yourCards.take(9),
          c(Suit.spades, Rank.king),
          c(Suit.diamonds, Rank.king),
          c(Suit.clubs, Rank.seven),
          c(Suit.diamonds, Rank.ten),
          c(Suit.diamonds, Rank.jack),
          c(Suit.hearts, Rank.eight),
          twoOfDiamonds,
        ],
      );
      final before = await container.read(playerDataProvider.future);
      // Asha shows on her first turn and picks the tiplu; Bina plays; Asha
      // then wins by discarding K♠.
      container
        ..controller.draw(DrawSource.stock)
        ..group(heartsRun)
        ..group(spadesRun)
        ..group(clubsRun)
        ..controller.showGroups();
      await container.controller.discard(container.idOf(twoOfDiamonds));
      container.controller
        ..pickTiplu(1)
        ..takeOver()
        ..draw(DrawSource.stock);
      await container.controller.discard(container.table.hand.last.id);
      container.controller
        ..takeOver()
        ..draw(DrawSource.stock)
        ..toggleSelected(container.idOf(kingOfSpades))
        ..declareWin();

      expect(container.table.view.winner?.name, 'Asha');
      expect(container.table.notice, 'Asha won the round.');
      // Several people share the device, so neither coins nor stats change.
      expect(await settledPlayerData(container), before);
    });

    test('everyone with more than 3 tunnellas chooses in turn before play', () {
      final four = [
        for (final rank in [Rank.two, Rank.five, Rank.nine, Rank.king])
          ...tunnellaOf(c(Suit.clubs, rank)),
      ];
      final container = twoPeople(asha: four, bina: four);

      expect(container.table.view.you.seat, 0);
      expect(container.table.openingChoice, hasLength(4));

      container.controller.chooseOpeningTunnellas([0, 1, 2]);
      expect(container.table.view.you.seat, 1, reason: 'Bina chooses next');
      expect(container.table.passingTo, 1);
      container.controller.takeOver();
      expect(container.table.openingChoice, hasLength(4));

      container.controller.chooseOpeningTunnellas([1, 2, 3]);
      expect(container.table.view.you.seat, 0, reason: 'Asha plays first');
      container.controller.takeOver();
      expect(container.table.openingChoice, isNull);
      container.controller.draw(DrawSource.stock);
      expect(container.table.view.youHaveDrawn, isTrue);
    });
  });

  group('Joker discard penalty', () {
    /// Shows the three runs and picks 7♥ as the tiplu, which makes the 7♣
    /// still in hand a joker, then draws on the next turn.
    Future<ProviderContainer> seenTheJoker({GameConfig? config}) async {
      final container = tableWith(config: config);
      await container.showThenDrawAgain();
      return container;
    }

    final sevenOfClubs = c(Suit.clubs, Rank.seven);

    test('discarding a joker after seeing it costs the penalty', () async {
      final container = await seenTheJoker();

      expect(
        container.controller.discardCostsPenalty(container.idOf(sevenOfClubs)),
        isTrue,
      );
    });

    test('an ordinary card costs nothing', () async {
      final container = await seenTheJoker();

      expect(
        container.controller.discardCostsPenalty(
          container.idOf(c(Suit.spades, Rank.king)),
        ),
        isFalse,
      );
    });

    test('nothing costs a penalty before the joker is seen', () async {
      final container = tableWith()..controller.draw(DrawSource.stock);

      expect(
        container.controller.discardCostsPenalty(container.idOf(sevenOfClubs)),
        isFalse,
      );
    });

    test(
      'the Superman costs the penalty even before the joker is seen',
      () async {
        const superman = PlayingCard.superman();
        final container = tableWith(
          yourHand: [
            for (final card in yourCards)
              card == sevenOfClubs ? superman : card,
          ],
        )..controller.draw(DrawSource.stock);

        expect(
          container.controller.discardCostsPenalty(container.idOf(superman)),
          isTrue,
        );
      },
    );

    test('nothing costs a penalty when the house rule is off', () async {
      final container = await seenTheJoker(
        config: GameConfig(playerCount: 2, jokerDiscardPenaltyEnabled: false),
      );

      expect(
        container.controller.discardCostsPenalty(container.idOf(sevenOfClubs)),
        isFalse,
      );
    });

    test('nothing costs a penalty outside the discard step', () async {
      final container = await seenTheJoker();
      final joker = container.idOf(sevenOfClubs);
      await container.controller.discard(
        container.idOf(c(Suit.spades, Rank.king)),
      );
      // The bot has played; it's the start of the next turn, before drawing.
      expect(container.table.view.isYourTurn, isTrue);
      expect(container.table.view.youHaveDrawn, isFalse);

      expect(container.controller.discardCostsPenalty(joker), isFalse);
    });

    test('an unknown card costs nothing', () async {
      expect(
        (await seenTheJoker()).controller.discardCostsPenalty(-1),
        isFalse,
      );
    });
  });

  group('Winning', () {
    // After showing the 3 runs with 7♥ as the tiplu and discarding 2♦, the
    // hand is K♠ K♦ 7♣ 10♦ J♦ Q♦ 8♥, and next turn a club is drawn:
    // discarding K♠ wins (K♦ 10♦ J♦ Q♦, and 7♣ 8♥ with the club), discarding
    // 10♦ doesn't.
    Future<ProviderContainer> readyToWin() async {
      final container = tableWith(yourHand: winnableCards);
      await container.showThenDrawAgain();
      return container;
    }

    test('a new match deals afresh with every total back at zero', () async {
      final container = await readyToWin();
      container.controller
        ..toggleSelected(container.idOf(kingOfSpades))
        ..declareWin();
      expect(container.table.roundScores, hasLength(1));
      expect(container.controller.canStartNewMatch, isTrue);

      container.controller.startNewMatch();

      expect(container.table.roundScores, isEmpty);
      expect(container.table.totals, everyElement(0));
      expect(container.table.view.winner, isNull);
      expect(container.table.roundNumber, 1);
    });

    test('a finished round counts toward the player\'s stats', () async {
      final container = await readyToWin();
      container.controller
        ..toggleSelected(container.idOf(kingOfSpades))
        ..declareWin();

      final stats = (await settledPlayerData(container)).stats;
      expect(stats.roundsPlayed, 1);
      expect(stats.roundsWon, 1);
      expect(stats.bestRound, container.table.roundScores.single.net[0]);
    });

    test('the cards that would win if discarded are known', () async {
      final container = await readyToWin();

      expect(
        container.table.winningDiscards,
        contains(container.idOf(kingOfSpades)),
      );
      expect(
        container.table.winningDiscards,
        isNot(contains(container.idOf(c(Suit.diamonds, Rank.ten)))),
      );
    });

    test('Win with nothing selected explains what to do', () async {
      final container = (await readyToWin())..controller.declareWin();

      expect(
        container.table.notice,
        'Select the card to discard, then tap Win.',
      );
    });

    test('a discard that does not win is refused', () async {
      final container = await readyToWin();
      container.controller
        ..toggleSelected(container.idOf(c(Suit.diamonds, Rank.ten)))
        ..declareWin();

      expect(
        container.table.notice,
        '10♦ does not leave a winning hand when discarded',
      );
      expect(container.table.view.winner, isNull);
    });

    test('a winning discard ends the round', () async {
      final container = await readyToWin();
      container.controller
        ..toggleSelected(container.idOf(kingOfSpades))
        ..declareWin();

      expect(container.table.view.winner?.name, 'You');
      expect(container.table.notice, 'You won the round!');
      expect(container.table.winningDiscards, isEmpty);
    });

    test('nothing wins before the joker is seen', () async {
      final container = tableWith()..controller.draw(DrawSource.stock);

      expect(container.table.winningDiscards, isEmpty);
    });
  });

  group('Bot turns', () {
    test('bots have personality names and avatar colours', () {
      final bot = tableWith().table.view.opponents.single;

      expect(BotPersonality.all.map((p) => p.name), contains(bot.name));
      expect(bot.avatarColor, isNotNull);
    });

    test('you cannot move while a bot is thinking', () async {
      final container = tableWith(
        thinkingTime: const Duration(milliseconds: 30),
      )..controller.draw(DrawSource.stock);

      final botsPlaying = container.controller.discard(
        container.idOf(twoOfDiamonds),
      );
      final bot = container.table.view.opponents.single.name;
      expect(container.table.view.isYourTurn, isFalse);

      container.controller.draw(DrawSource.stock);
      expect(container.table.notice, 'Wait for $bot to play.');
      expect(container.table.view.youHaveDrawn, isFalse);

      await botsPlaying;
      expect(container.table.view.isYourTurn, isTrue);
      container.controller.draw(DrawSource.stock);
      expect(container.table.view.youHaveDrawn, isTrue);
    });

    test('each bot\'s latest discard is shown at its seat', () async {
      final container = tableWith()..controller.draw(DrawSource.stock);

      await container.controller.discard(container.idOf(twoOfDiamonds));

      final bot = container.table.view.opponents.single;
      expect(bot.lastDiscard, isNotNull);
      expect(container.table.view.you.lastDiscard, twoOfDiamonds);
    });

    test('once the round is over, moves are refused', () async {
      final container = await botWinsOnItsSecondTurn();

      container.controller.draw(DrawSource.stock);

      expect(container.table.notice, 'The round is over.');
    });

    test(
      'a bot that plays first moves as soon as the table is ready',
      () async {
        final container = tableWith(firstSeat: 1);
        expect(container.table.view.isYourTurn, isFalse);

        await Future<void>.delayed(Duration.zero);
        await container.controller.botsSettled;

        expect(container.table.view.isYourTurn, isTrue);
      },
    );

    test('a game with Hard bots plays normally', () async {
      final container = ProviderContainer(
        overrides: [
          randomProvider.overrideWithValue(Random(4)),
          botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
          botDifficultyProvider.overrideWithValue(BotDifficulty.hard),
          gameConfigProvider.overrideWithValue(GameConfig(playerCount: 3)),
        ],
      );
      addTearDown(container.dispose);

      for (
        var turn = 0;
        turn < 5 && container.table.view.winner == null;
        turn++
      ) {
        container.controller.draw(DrawSource.stock);
        await container.controller.discard(container.table.hand.last.id);
      }
      expect(container.table.view.opponents, hasLength(2));
    });
  });

  group('Match', () {
    /// A round you win on your second turn, discarding K♠.
    Future<ProviderContainer> wonByYou({MatchSetup? setup}) async {
      final container = tableWith(setup: setup, yourHand: winnableCards);
      await container.showThenDrawAgain();
      container.controller
        ..toggleSelected(container.idOf(kingOfSpades))
        ..declareWin();
      return container;
    }

    test('a finished round is scored and added to the match', () async {
      final container = await wonByYou();
      final table = container.table;

      expect(table.roundScores, hasLength(1));
      expect(table.roundScores.single.winner, 0);
      expect(table.totals, table.roundScores.single.net);
      expect(table.seatNames.first, 'You');
      expect(table.seatNames[1], table.view.opponents.single.name);
    });

    test('your result each round moves your coins', () async {
      final container = await wonByYou();

      expect(
        (await settledPlayerData(container)).coins,
        PlayerData.startingCoins + container.table.totals[0],
      );
    });

    /// A round the bot wins on its second turn.
    Future<ProviderContainer> wonByTheBot({MatchSetup? setup}) =>
        botWinsOnItsSecondTurn(setup: setup);

    test('a round won by a bot is scored too', () async {
      final container = await wonByTheBot();

      expect(container.table.roundScores.single.winner, 1);
    });

    group('At a stake table', () {
      // Medium bots, so the bot's win comes when the fixtures expect it.
      const fiftyTable = StakeTable(
        stake: 50,
        minBalance: 5000,
        gamesToUnlock: 75,
        difficulty: BotDifficulty.medium,
      );
      final atFifty = MatchSetup.atTable(fiftyTable, playerCount: 2);

      test('its bots play at the table\'s difficulty', () {
        expect(atFifty.difficulty, BotDifficulty.medium);
        expect(atFifty.stake, 50);
      });

      test('a round won pays its points × the stake', () async {
        final container = await wonByYou(setup: atFifty);
        final points = container.table.roundScores.single.net[0];

        final data = await settledPlayerData(container);
        expect(points, greaterThan(0));
        expect(data.coins, PlayerData.startingCoins + points * 50);
      });

      test('a round lost costs its points × the stake', () async {
        final container = await wonByTheBot(setup: atFifty);
        final points = container.table.roundScores.single.net[0];

        final data = await settledPlayerData(container);
        expect(points, lessThan(0));
        expect(data.coins, PlayerData.startingCoins + points * 50);
      });

      test('a loss bigger than the balance leaves it at zero', () async {
        const top = StakeTable(
          stake: 100000,
          minBalance: 0,
          gamesToUnlock: 1,
          difficulty: BotDifficulty.hard,
        );
        final container = await wonByTheBot(
          setup: MatchSetup.atTable(top, playerCount: 2),
        );

        expect((await settledPlayerData(container)).coins, 0);
      });

      test('a round won or lost counts as a game at the table', () async {
        final won = await wonByYou(setup: atFifty);
        final lost = await wonByTheBot(setup: atFifty);

        expect((await settledPlayerData(won)).gamesAt(50), 1);
        expect((await settledPlayerData(lost)).gamesAt(50), 1);
      });

      test('a game without a stake counts toward no table', () async {
        final container = await wonByYou();

        expect((await settledPlayerData(container)).gamesAtStake, isEmpty);
      });
    });

    test('Next round only works once the round is over', () {
      final container = tableWith()..controller.startNextRound();

      expect(container.table.roundNumber, 1);
    });

    test('Next round deals afresh, rotates the first player, and keeps the '
        'totals and the bots', () async {
      final container = await wonByYou();
      final names = container.table.seatNames;
      final totals = container.table.totals;

      container.controller.startNextRound();
      final table = container.table;

      expect(table.roundNumber, 2);
      expect(table.view.winner, isNull);
      expect(table.hand, hasLength(yourCards.take(9).length + 7));
      expect(table.groups, isEmpty);
      expect(
        table.view.opponents.map((s) => s.lastDiscard),
        everyElement(isNull),
      );
      expect(table.roundScores, hasLength(1));
      expect(table.totals, totals);
      expect(table.seatNames, names);
      // The bot (seat 1) goes first this time; once it has played, it's
      // your turn.
      expect(table.view.currentSeat, 1);
      await Future<void>.delayed(Duration.zero);
      await container.controller.botsSettled;
      expect(container.table.view.isYourTurn, isTrue);
    });
  });
}
