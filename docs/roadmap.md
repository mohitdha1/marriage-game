# Marriage Card Game App — Roadmap

A phased plan to build a Bhoos-quality Marriage card game in Flutter, scoped for a solo developer working part-time. MVP = Phases 0–3. Online multiplayer (Phase 5) is a separate later project.

**Target:** single-player vs bots + local multiplayer, polished enough to ship on the Play Store and strong enough to anchor a junior SWE portfolio.

---

## Phase 0 — Dart & Flutter foundations (2–3 weeks)

You're learning Java; Dart will feel familiar (same C-style roots, classes, null safety). Don't build the game yet — just get comfortable.

- Dart basics: variables, classes, enums, lists/maps, null safety, futures/async
- Flutter basics: widgets, layout (Row/Column/Stack), state (setState), navigation
- Build 2–3 tiny practice apps first (a counter, a to-do list, a simple card-flip demo)
- Pick a state management approach for the game and stick with it — **Riverpod** is the recommended default (simpler than Bloc, scales fine for a card game)

**Milestone:** you can build a small Flutter app with multiple screens from scratch without a tutorial holding your hand.

---

## Phase 1 — Game logic engine, pure Dart (3–4 weeks)

No UI at all. This is the brain of the game, written as plain Dart classes you can unit-test. This phase is also the most interview-valuable part of the whole project.

1. **Card model** — `Suit` and `Rank` enums, a `PlayingCard` class, equality so duplicate cards across 3 decks compare correctly
2. **Deck** — 3 standard decks, shuffle (Fisher–Yates), deal 21 cards each to 2–5 players
3. **Hand evaluation** — detect in a hand:
   - Pure sequence (3+ consecutive, same suit)
   - Trial (3 same rank, different suits)
   - Tunnella (3 identical cards — same suit AND rank, possible with 3 decks)
4. **Joker system** — flip a joker card; derive tiplu (same suit+rank), jhiplu/poplu (one rank lower/higher, same suit), alter cards, ordinary jokers; jokers substitute in sequences/trials
5. **Joker-seen flow** — before seeing the joker a player must show 3 pure sequences/tunnellas and discard; after that, build remaining sets with joker help
6. **Scoring engine** — points per round including marriage (K–Q same suit) bonuses, doublee/tunnella bonuses; total across rounds; winner determination
7. **Unit tests for all of it** — every rule above gets tests. Aim for the scoring engine to be fully covered. This is portfolio gold: "rules engine with 100+ unit tests" reads great on a resume and gives you real stories for interviews

**Milestone:** a console/text version of the game runs end-to-end — deal, turns, joker-seen, scoring — driven by the engine, all green tests.

---

## Phase 2 — Single-player Flutter UI vs bots (6–8 weeks)

Now put a face on the engine. One screen at a time.

1. **Table screen** — opponents' avatars/names around a table, draw and discard piles in the center, your fanned hand at the bottom
2. **Card widgets** — tappable cards, select/highlight, drag or tap to draw, tap to discard; a **Sort** button (by suit, then rank)
3. **Turn flow** — playable cards subtly highlighted, turn indicator on the active player, joker-reveal moment with a card flip
4. **Bot AI (rule-based, 3 difficulties):**
   - *Easy:* random-ish legal moves
   - *Medium:* keeps pure sequences, discards high deadwood, uses jokers sensibly
   - *Hard:* tracks discards, avoids feeding opponents, plans joker-seen timing
   - Give bots names/avatars and distinct play styles — cheap personality, big feel win
5. **Scoreboard screen** — per-round breakdown (sequences, trials, tunnellas, marriages, joker bonuses), running totals
6. **Sound effects** — shuffle, card snap, select click, win jingle (royalty-free packs are fine to start)

**Milestone:** you can play a full game against 4 bots on your phone, start to finish, with sound and scoring.

---

## Phase 3 — Polish: the part that makes it look like Bhoos (3–4 weeks)

This is the 40% that separates "side project" from "real app." Budget real time here.

- Custom card faces and card backs (commissioned or quality asset pack — this is the single highest-impact spend)
- Table themes: at least 2–3 (e.g., classic Nepali, dark modern, festive) via a swappable theme system
- Full animation set: cards flying out on deal, smooth draw/discard slides, flip on joker reveal, win celebration
- Haptics: subtle vibration on your turn, on wins
- Lobby screen: big **Quick Play** button, bot difficulty picker, settings (sound, vibration, variations like Murder/Kidnap later)
- App icon, splash screen, Play Store screenshots and listing copy
- Playtest with friends/family; fix everything that confuses a first-time player

**Milestone:** the app *feels* premium. Show it to someone without explaining and they get it immediately.

**→ MVP complete here. This alone is shippable and portfolio-ready.**

---

## Phase 4 — Local multiplayer (2–3 weeks)

- **Pass-and-play** on one device (hand hidden between turns) — easy, do it first
- **Hotspot/LAN play** — one phone hosts, others join over the same Wi-Fi/hotspot; simple socket-based sync of game state
- Reuse the Phase 1 engine as the single source of truth so rules stay consistent

**Milestone:** play a real game with friends in the same room, each on their own phone.

---

## Phase 5 — Online multiplayer (2–3 months, later)

Do not start this until the MVP is shipped. It's a second project wearing the first project's clothes.

- Backend choice: **Firebase Realtime Database** (fastest solo path) or a custom **Dart/Node websocket server** (more control, more work)
- Auth, game rooms, matchmaking, reconnect handling when someone's network drops mid-game
- Server-authoritative game state (clients send moves, server validates) to prevent cheating
- Leaderboards, friend lists, chat/emojis at the table

**Milestone:** two strangers can find each other and finish a full game online.

---

## Phase 6 — Publish & iterate

- Google Play: $25 one-time developer fee; Apple App Store: $99/year (Android first is fine)
- **Play-money / virtual chips only.** No real-money wagering — the stores will reject gambling mechanics
- Privacy policy page (required by Play Store), even for a simple game
- Closed beta with friends → open release → iterate on crash reports and feedback

---

## Rough timeline (part-time, ~8–10 hrs/week)

| Phase | Duration |
|---|---|
| 0 — Foundations | 2–3 weeks |
| 1 — Logic engine | 3–4 weeks |
| 2 — UI + bots | 6–8 weeks |
| 3 — Polish | 3–4 weeks |
| **MVP total** | **~4–5 months** |
| 4 — Local multiplayer | +2–3 weeks |
| 5 — Online multiplayer | +2–3 months |

These are honest estimates for someone early in the journey — they assume learning as you go, which is the point.

## What this gives your job hunt

- **Portfolio:** a shipped Play Store app beats tutorial projects every time
- **Resume lines:** "Built a Flutter card game with a fully unit-tested rules engine," "implemented rule-based bot AI with 3 difficulty tiers"
- **Interview stories:** real debugging war stories (race conditions in turn flow, scoring edge cases) — interviewers love these
- **Skills demonstrated:** Dart/Flutter, state management, software testing, UI animation, and later backend/networking

## Ground rules

1. Finish each phase's milestone before starting the next — no skipping to online multiplayer
2. The Phase 1 engine stays UI-independent forever; the UI only *displays* what the engine decides
3. Commit to GitHub regularly; the commit history is part of the portfolio
4. When stuck for more than a day on one problem, ask — that's what I'm here for
