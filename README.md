# Marriage

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
- **Phase 2, the Flutter UI and bots, is in progress.** The landscape table
  screen is playable against bots at three difficulty levels: draw, discard,
  group and show sets, see the joker, win, and follow the scores round by
  round, with sound effects.

### How the code is organised

| Path | What's there |
|---|---|
| `lib/engine/` | The rules engine: cards, the shoe, sets, jokers, hands, rounds, scoring. Pure Dart with **no Flutter imports**, and the single source of truth for the rules. |
| `lib/bots/` | Computer players at three levels (Easy, Medium, Hard) with named personalities. Pure Dart; they only see what a player at the table could. |
| `lib/ui/` | The Flutter app: Riverpod state (`ui/state/`) and the table screen's widgets (`ui/table/`). |
| `lib/console/` | The terminal version of the game. It only turns commands into engine calls and engine state into text. |
| `bin/marriage.dart` | Command-line entry point for the console game. |
| `tool/generate_sounds.dart` | Synthesises the placeholder sound effects into `assets/sounds/` (run with `dart run tool/generate_sounds.dart`). |
| `test/` | Unit tests for every engine rule and the bots, widget tests for the table screen, and tests that script whole console games. |
| `docs/` | [`roadmap.md`](docs/roadmap.md) (phased build plan) and [`app-spec.md`](docs/app-spec.md) (product spec). |

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
| `show 1 2 3, 4 5 6, 7 8 9` | Show pure sets to see the joker |
| `doublees 1 2, 3 4, …` | Show 7 doublees to see the joker |
| `discard 5` or `x 5` | Discard a card and end your turn |
| `win 5` | Discard a card and finish the round |
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
