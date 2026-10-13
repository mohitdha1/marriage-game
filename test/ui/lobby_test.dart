import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/engine/card.dart';
import 'package:marriage_game/engine/game_config.dart';
import 'package:marriage_game/engine/round.dart';
import 'package:marriage_game/main.dart';
import 'package:marriage_game/net/connection.dart';
import 'package:marriage_game/net/game_host.dart';
import 'package:marriage_game/net/remote_session.dart';
import 'package:marriage_game/net/room_code.dart';
import 'package:marriage_game/net/wire.dart';
import 'package:marriage_game/ui/home/game_setup.dart';
import 'package:marriage_game/ui/lobby/host_lobby_screen.dart';
import 'package:marriage_game/ui/lobby/join_screen.dart';
import 'package:marriage_game/ui/settings/house_rules_screen.dart';
import 'package:marriage_game/ui/settings/preferences.dart';
import 'package:marriage_game/ui/settings/settings.dart';
import 'package:marriage_game/ui/sound/sound_effects.dart';
import 'package:marriage_game/ui/state/table_controller.dart';
import 'package:marriage_game/ui/state/table_view.dart';
import 'package:marriage_game/ui/table/table_screen.dart';

const c = PlayingCard.new;

/// Shows [home] at phone size with the guide done and sound off, plus any
/// [overrides].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = const Size(844, 390)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(
          InMemoryPreferences({
            'profile.name': 'Mohit',
            'guide.done': 'draw,discard,sets,joker',
          }),
        ),
        soundEffectsProvider.overrideWithValue(const SilentSoundEffects()),
        randomProvider.overrideWithValue(Random(0)),
        botThinkingTimeProvider.overrideWithValue(() => Duration.zero),
        ...overrides,
      ],
      child: MarriageApp(home: home),
    ),
  );
}

/// Lets real network traffic happen, then redraws.
Future<void> letNetworkRun(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

/// What a host shows a joined device: a table from Bina's seat.
SeatUpdate binasFirstLook() {
  final round =
      Round.fromCards(
          config: GameConfig(playerCount: 2),
          random: Random(0),
          hands: [
            [c(Suit.spades, Rank.king)],
            [c(Suit.clubs, Rank.four), c(Suit.diamonds, Rank.nine)],
          ],
          stock: [c(Suit.clubs, Rank.five)],
          discardPile: [c(Suit.clubs, Rank.king)],
        )
        ..showOpeningTunnellas(0, [])
        ..showOpeningTunnellas(1, []);
  return SeatUpdate(
    view: TableView.fromRound(
      round,
      humanSeat: 1,
      nameOf: (seat) => ['Mohit', 'Bina'][seat],
    ),
    handProgress: null,
    winningCards: const [],
    roundNumber: 1,
    seatNames: const ['Mohit', 'Bina'],
    roundScores: const [],
    totals: const [0, 0],
    jokerPenalty: true,
  );
}

/// A lobby kept in memory: guests join by name, each with an in-memory
/// link whose far end is kept here.
class FakeLobby implements Lobby {
  @override
  String hostName = 'Mohit';
  final _guests = <Guest>[];
  final _changes = StreamController<List<String>>.broadcast(sync: true);
  int _seats = 4;
  var started = false;
  var closed = false;

  /// The guests' devices' ends of their links.
  final farEnds = <Connection>[];

  void join(String name) {
    final (hostEnd, guestEnd) = InMemoryConnection.pair();
    _guests.add(Guest(name, hostEnd, 'token-$name'));
    farEnds.add(guestEnd);
    _changes.add(names);
  }

  @override
  List<String> get names => [hostName, for (final g in _guests) g.name];

  @override
  int get seats => _seats;

  @override
  Stream<List<String>> get changes => _changes.stream;

  @override
  void resize(int seats) {
    if (seats < names.length) return;
    _seats = seats;
    _changes.add(names);
  }

  @override
  Map<int, Guest> start() {
    started = true;
    return {for (final (i, g) in _guests.indexed) i + 1: g};
  }

  @override
  Stream<Rejoin> get rejoins => const Stream.empty();

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('Hosting', () {
    testWidgets('the lobby shows the room code and who\'s at the table', (
      tester,
    ) async {
      final lobby = FakeLobby();
      await pumpScreen(
        tester,
        const HostLobbyScreen(),
        overrides: [
          localAddressProvider.overrideWithValue(() async => '192.168.1.23'),
          openLobbyProvider.overrideWithValue((name, seats) async {
            lobby.hostName = name;
            return lobby;
          }),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(roomCodeFor('192.168.1.23')), findsOneWidget);
      expect(find.text('Mohit'), findsOneWidget);
      expect(find.text('Bot'), findsNWidgets(3));

      // Bina joins from her phone.
      lobby.join('Bina');
      await tester.pump();
      expect(find.text('Bina'), findsOneWidget);
      expect(find.text('Bot'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('lobby-seats-2')));
      await tester.pump();
      expect(find.text('Bot'), findsNothing);
      expect(find.text('Start the game'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lobby-start')));
      await tester.pumpAndSettle();
      expect(find.byType(TableScreen), findsOneWidget);
      final table = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      ).read(tableProvider);
      expect(table.seatNames, ['Mohit', 'Bina']);
      expect(lobby.started, isTrue);

      // Leaving the table closes the lobby and its links.
      await tester.pumpWidget(const SizedBox());
      expect(lobby.closed, isTrue);
    });

    testWidgets('alone in the lobby, Start plays against bots', (tester) async {
      await pumpScreen(
        tester,
        const HostLobbyScreen(),
        overrides: [
          localAddressProvider.overrideWithValue(() async => '10.0.0.2'),
          openLobbyProvider.overrideWithValue(
            (name, seats) async => FakeLobby(),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Start with bots'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('lobby-start')));
      await tester.tap(find.byKey(const Key('lobby-start')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TableScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      );
      expect(container.read(matchSetupProvider).isPassAndPlay, isFalse);
      final table = container.read(tableProvider);
      expect(table.seatNames.first, 'Mohit');
      expect(table.view.opponents, hasLength(3));
      expect(table.passingTo, isNull);
    });

    testWidgets('the lobby opens the house rules, and the game plays by '
        'them', (tester) async {
      final lobby = FakeLobby();
      await pumpScreen(
        tester,
        const HostLobbyScreen(),
        overrides: [
          localAddressProvider.overrideWithValue(() async => '10.0.0.2'),
          openLobbyProvider.overrideWithValue((name, seats) async => lobby),
        ],
      );
      await tester.pump();
      await tester.pump();
      lobby.join('Bina');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('house-rules-button')));
      await tester.tap(find.byKey(const Key('house-rules-button')));
      await tester.pumpAndSettle();
      expect(find.byType(HouseRulesScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('rule-superman')));
      await tester.tap(find.byKey(const Key('rule-superman')));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lobby-start')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      );
      expect(container.read(gameConfigProvider).supermanCardEnabled, isTrue);
    });

    testWidgets('without Wi-Fi, the lobby says how to fix it', (tester) async {
      await pumpScreen(
        tester,
        const HostLobbyScreen(),
        overrides: [localAddressProvider.overrideWithValue(() async => null)],
      );
      await tester.pump();

      expect(find.byKey(const Key('lobby-problem')), findsOneWidget);
      expect(find.textContaining('Connect to Wi-Fi'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('House rules', () {
    testWidgets('every rule has a switch and a line on what it does', (
      tester,
    ) async {
      await pumpScreen(tester, const HouseRulesScreen());

      for (final description in [
        HouseRulesScreen.manCardsDescription,
        HouseRulesScreen.supermanDescription,
        HouseRulesScreen.alterDescription,
        HouseRulesScreen.penaltyDescription,
      ]) {
        await tester.scrollUntilVisible(find.text(description), 50);
        expect(find.text(description), findsOneWidget);
      }
      expect(HouseRulesScreen.manCardsDescription, contains('1 = 5, 2 = 15'));
      expect(find.byKey(const Key('mode-kidnap')), findsOneWidget);
    });

    testWidgets('switching a rule saves it', (tester) async {
      await pumpScreen(tester, const HouseRulesScreen());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HouseRulesScreen)),
      );

      await tester.tap(find.byKey(const Key('mode-murder')));
      await tester.tap(find.byKey(const Key('rule-man-cards')));
      await tester.pump();

      final rules = container.read(settingsProvider).rules;
      expect(rules.mode, GameMode.murder);
      expect(rules.manCards, isTrue);
      expect(find.text(describeMode(GameMode.murder)), findsOneWidget);
    });

    testWidgets('fits a small phone', (tester) async {
      await pumpScreen(tester, const HouseRulesScreen());
      tester.view.physicalSize = const Size(667, 375);
      await tester.pump();

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('rule-joker-penalty')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rule-joker-penalty')).hitTestable(),
        findsOneWidget,
      );
    });
  });

  group('Joining', () {
    /// The host's end of a link handed to the join screen, and the screen.
    Future<Connection> pumpJoin(WidgetTester tester) async {
      final (hostEnd, guestEnd) = InMemoryConnection.pair();
      await pumpScreen(
        tester,
        const JoinScreen(),
        overrides: [
          joinGameProvider.overrideWithValue((address, name) async {
            final session = RemoteSession(guestEnd);
            session.send(Hello(name));
            return session;
          }),
        ],
      );
      return hostEnd;
    }

    testWidgets('a mistyped code is caught before connecting', (tester) async {
      await pumpJoin(tester);

      await tester.enterText(find.byKey(const Key('join-code')), 'nope');
      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pump();

      expect(find.textContaining('That isn\'t a room code'), findsOneWidget);
    });

    testWidgets('join, wait in the lobby, then the table opens when the host '
        'starts', (tester) async {
      final host = await pumpJoin(tester);
      final heard = <WireMessage>[];
      host.messages.listen(heard.add);

      await tester.enterText(
        find.byKey(const Key('join-code')),
        roomCodeFor('192.168.1.23'),
      );
      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pump();
      expect((heard.single as Hello).name, 'Mohit');

      host
        ..send(const Welcome(1, token: 't'))
        ..send(const LobbyUpdate(names: ['Asha', 'Mohit'], seats: 3));
      await tester.pump();
      await tester.pump();
      expect(find.text('Waiting for Asha to start…'), findsOneWidget);

      host.send(binasFirstLook());
      await tester.pumpAndSettle();
      expect(find.byType(TableScreen), findsOneWidget);
      final table = ProviderScope.containerOf(
        tester.element(find.byType(TableScreen)),
      ).read(tableProvider);
      expect(table.view.you.name, 'Bina');
      expect(table.hand.map((h) => h.card), [
        c(Suit.clubs, Rank.four),
        c(Suit.diamonds, Rank.nine),
      ]);
    });

    testWidgets('a host that turns you away says why', (tester) async {
      final host = await pumpJoin(tester);
      await tester.enterText(
        find.byKey(const Key('join-code')),
        roomCodeFor('10.0.0.2'),
      );
      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pump();

      host.send(const Rejected('The table is full.'));
      await tester.pump();
      await tester.pump();

      expect(find.text('The table is full.'), findsOneWidget);
    });

    testWidgets('a game that can\'t be reached says what to check', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const JoinScreen(),
        overrides: [
          joinGameProvider.overrideWithValue(
            (address, name) async =>
                throw const SocketException('No route to host'),
          ),
        ],
      );
      await tester.enterText(
        find.byKey(const Key('join-code')),
        roomCodeFor('10.0.0.2'),
      );
      await tester.tap(find.byKey(const Key('join-button')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('same Wi-Fi as the host'), findsOneWidget);
    });
  });
}
