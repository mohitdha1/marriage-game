# Marriage

[![CI](https://github.com/mohitdha1/marriage-game/actions/workflows/ci.yml/badge.svg)](https://github.com/mohitdha1/marriage-game/actions/workflows/ci.yml)

A Flutter version of **Marriage**, the 3-deck rummy-style card game popular
in Nepal, built as a portfolio project while learning Dart and Flutter.

## About the project

Players are dealt 21 cards each from three shuffled decks and race to arrange
their whole hand into sets: sequences, trials and tunnellas. Before a player
can use jokers, they must show 3 pure sets (or 7 doublees) to "see the
joker". Points come from maal cards (tiplu, jhiplu, poplu, alter), marriages
and tunnellas, and are settled between all players at the end of each round.

The game is built in phases (see [`docs/roadmap.md`](docs/roadmap.md)):

- **Phase 1, the rules engine, is complete.** A pure-Dart engine runs a full
  game, from the deal through turns, the joker-seen flow, winning and
  scoring, and you can play it in the terminal.
- **Phase 2, the Flutter UI and bots, is complete.** The landscape table
  screen is playable against bots at three difficulty levels: draw, discard,
  group and show sets, see the joker, win, and follow the scores round by
  round, with sound effects.
- **Phase 3, polish, is complete.** Printed-style cards with classic
  court figures, three table themes with textured felt and a wooden rim,
  animated dealing, draws and discards, a win celebration, sounds and
  vibration, drag-up and flick discarding, Quick Play and a custom game
  setup, a first-time guide, an app icon and splash screen, and a draft
  store listing.
- **Phase 4, local multiplayer, is built.** Pass and play: 2 to 5 people
  share one device, and the table is covered between turns so nobody sees
  another's cards. Over Wi-Fi or a phone's hotspot: one phone hosts and
  shows a room code, friends join from theirs, and bots fill any empty
  seats. The host runs the game and sends each phone only what its player
  may see. Tested between a phone and an emulator; a game with friends on
  their own phones comes next.

### How the code is organised

| Path | What's there |
|---|---|
| `lib/engine/` | The rules engine: cards, the shoe, sets, jokers, hands, rounds, scoring. Pure Dart with **no Flutter imports**, and the single source of truth for the rules. |
| `lib/bots/` | Computer players at three levels (Easy, Medium, Hard) with named personalities. Pure Dart; they only see what a player at the table could. |
| `lib/ui/` | The Flutter app: the home screen, Quick Play and game setup, and coins (`ui/home/`), settings, profile and rules (`ui/settings/`), Riverpod state for the table (`ui/state/`), the table screen's widgets and card art (`ui/table/`), table themes and felt (`ui/theme/`), the scoreboard, sounds and vibration. |
| `lib/net/` | Playing across devices: room codes, the messages phones send each other and their JSON form, the host's lobby over WebSockets, and the link a joining phone keeps to the host. Pure Dart, tested over real sockets on the loopback address. |
| `lib/console/` | The terminal version of the game. It only turns commands into engine calls and engine state into text. |
| `bin/marriage.dart` | Command-line entry point for the console game. |
| `tool/import_sounds.dart` | Builds the sound effects in `assets/sounds/` from Kenney's sound packs: cuts, fades and levels each one (run on macOS with `dart run tool/import_sounds.dart <folder with the unzipped packs>`). |
| `tool/render_branding.dart` | Draws the app icon and splash logo with the game's own card faces into `assets/branding/` (run with `flutter test tool/render_branding.dart`, then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`). |
| `test/` | Unit tests for every engine rule and the bots, widget tests for the table screen, and tests that script whole console games. |
| `tool/render_screenshots.dart` | Renders the store screenshots from the app's real screens into `docs/store/screenshots/` (run with `flutter test tool/render_screenshots.dart`). |
| `docs/` | [`roadmap.md`](docs/roadmap.md) (phased build plan), [`app-spec.md`](docs/app-spec.md) (product spec), and [`store/listing.md`](docs/store/listing.md) (Play Store copy and assets). |

## Running the console game

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install),
which includes Dart. From the project folder:

```sh
flutter pub get
dart run bin/marriage.dart
```

You play the first seat against bots. Options:

```sh
dart run bin/marriage.dart --players=3            # 2 to 5 players (default 5)
dart run bin/marriage.dart --difficulty=hard      # easy, medium or hard bots
dart run bin/marriage.dart --seed=42              # repeatable shuffle
dart run bin/marriage.dart --bots-only --rounds=3 # watch bots play 3 rounds
dart run bin/marriage.dart --help
```

Your hand is listed with numbers, sorted by suit and then rank. On your turn,
type:

| Command | What it does |
|---|---|
| `draw` or `d` | Draw from the stock |
| `take` or `t` | Take the top card of the discard pile |
| `show 1 2 3, 4 5 6, 7 8 9` | Show pure sets; you see the joker after your discard |
| `doublees 1 2, 3 4, …` | Show 7 doublees; you see the joker after your discard |
| `discard 5` or `x 5` | Discard a card and end your turn (a discard that leaves a winning hand wins) |
| `win 5` | Discard a card and finish the round (not on the turn you show) |
| `hand` or `h` | Show the table and your hand again |
| `help` | List the commands |
| `quit` or `q` | Stop the game |

If you try something the rules don't allow, the game tells you why and
your turn carries on.

## Running the tests

```sh
flutter test                 # every test
flutter test test/engine     # just the rules engine
flutter test test/console    # just the console game
flutter analyze              # static analysis
```

## Credits

- **Court card figures** (the jacks, queens and kings in
  `assets/cards/court/`) come from
  [Vector Playing Cards](https://github.com/notpeter/Vector-Playing-Cards),
  originally drawn by [Byron Knoll](http://www.byronknoll.com/). They are
  released into the public domain, or under the
  [WTFPL](http://www.wtfpl.net/) where public domain isn't recognised, and
  may be used in commercial software. The figure panels were cropped from
  the SVGs and resized; everything else on the cards is drawn in Flutter.
- **Avatars** are original, drawn in code by `lib/ui/home/player_avatar.dart`
  from the looks in `lib/data/avatar_look.dart`; no image files are used.
- **Sound effects** come from three packs by [Kenney](https://kenney.nl),
  released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  (public domain, commercial use allowed, no credit required). Each was cut,
  faded and levelled by `tool/import_sounds.dart`:

  | Sound | Pack | File |
  |---|---|---|
  | Shuffle (the deal) | [Casino Audio](https://kenney.nl/assets/casino-audio) | `card-shuffle.ogg` |
  | Card snap (draw and discard) | [Casino Audio](https://kenney.nl/assets/casino-audio) | `card-place-2.ogg` |
  | Select | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | `select_001.ogg` |
  | Your turn | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | `glass_001.ogg` |
  | Joker reveal | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | `maximize_006.ogg` |
  | Win | [Music Jingles](https://kenney.nl/assets/music-jingles) | `jingles_STEEL02.ogg` |
  | Someone else wins | [Music Jingles](https://kenney.nl/assets/music-jingles) | `jingles_PIZZI01.ogg` |
