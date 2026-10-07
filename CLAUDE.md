# marriage_game

A Flutter portfolio project built while learning Dart/Flutter, aimed at junior SWE job applications.

## Background

- The developer is an experienced Java developer but new to Dart/Flutter. Explanations should lean on Java/OOP analogies where helpful rather than assuming prior Dart/Flutter knowledge.
- This is a portfolio project — code quality and clear structure matter as much as working features.

## Architecture

- **State management:** Riverpod.
- **Game engine:** lives in `lib/engine/`. It is pure Dart — **zero Flutter imports** in this directory. It is the single source of truth for game rules and state; UI and widgets read from it, never the other way around.
- Every rule implemented in the engine needs a corresponding unit test. Don't consider an engine change done until it has test coverage in `test/`.

## Project plan

The full phased roadmap lives in `docs/roadmap.md` — read it for details on any phase. We are currently on **Phase 1**.

Phase order (don't skip ahead):
0. Dart & Flutter foundations
1. Game logic engine (pure Dart) — current phase
2. Single-player Flutter UI vs bots
3. Polish (card art, themes, animation, sound) — MVP complete after this
4. Local multiplayer (pass-and-play, LAN/hotspot)
5. Online multiplayer (separate later project, not part of MVP)
6. Publish & iterate

Ground rules from the roadmap:
1. Finish each phase's milestone before starting the next — no skipping to online multiplayer
2. The Phase 1 engine stays UI-independent forever; the UI only *displays* what the engine decides
3. Commit to GitHub regularly; the commit history is part of the portfolio
4. When stuck for more than a day on one problem, ask

## Working style

- When asked "how do I do X," explain the approach first and let the developer attempt it before writing complete code — unless explicitly told to "just write it."
- Keep changes small: one feature per session. Don't bundle unrelated work into the same change.
