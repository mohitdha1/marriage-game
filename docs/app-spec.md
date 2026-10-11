# Marriage Card Game — App Roadmap

Everything the app itself should include, in build order. No study plan — this is the product spec. MVP = sections 1–7 shipped.

---

## 1. Core game rules to implement

- 3 decks, 2–5 players, 21 cards each
- Joker/maal flip each round: tiplu, jhiplu/poplu, alter cards, ordinary jokers
- Joker-seen flow: show 3 pure sequences/tunnellas + discard before seeing the joker
- Valid sets: pure sequence, trial, tunnella; marriage = K–Q of the same suit (bonus points), doublee bonuses
- Per-round scoring + match totals + winner
- Configurable variations (toggles in settings): Murder, Kidnap, man cards, superman card, player count

## 2. Game modes (in order of build)

1. **Quick Play vs bots** — one tap, default settings, straight into a game (MVP)
2. **Custom table vs bots** — choose player count, bot difficulty, variations (MVP)
3. **Pass-and-play** — one device, hidden hands between turns (v2)
4. **Hotspot/LAN** — host on one phone, friends join over Wi-Fi/hotspot (v2)
5. **Online** — rooms, matchmaking, friend invites (later, needs backend)

## 3. Screens

- **Splash** — logo, quick load
- **Home/lobby** — big Quick Play button; Custom Game; Play with Friends; How to Play; Settings; coin balance visible
- **Table** — the core screen, gets the most effort (see section 4)
- **Scoreboard** — per-round breakdown, not just totals (see section 6)
- **Results** — winner banner, stats, Rematch and Home buttons
- **How to Play** — illustrated rules + a practice hand against easy bots
- **Settings** — sound, vibration, theme, card style, variations, language (English + Nepali)
- **Profile/stats** — games played, win rate, best scores

## 4. Table screen — where quality lives

- Opponents arranged around the table with avatars, names, and card counts
- Draw and discard piles center-table; last discarded card clearly visible
- Your hand fanned at the bottom: tap to select, tap/drag to draw and discard
- **Sort button** (by suit, then rank) — players expect this
- Playable cards subtly highlighted; dead cards dimmed
- Turn indicator: glow/timer ring on the active player, always obvious whose move it is
- Joker reveal moment: card flip animation + banner showing the maal before play continues
- Bot "thinking" pause so opponents feel human, not instant

## 5. Bots

- 3 difficulties with genuinely different heuristics:
   - *Easy:* mostly legal moves, sloppy with jokers
   - *Medium:* protects sequences, discards high deadwood, uses jokers sensibly
   - *Hard:* tracks discards, avoids feeding opponents, times its joker-seen
- Named personalities with avatars (Nepali-flavored names), distinct play styles
- Difficulty selectable per custom game; Quick Play uses medium

## 6. Scoreboard and results

- Round breakdown: pure sequences, trials, tunnellas, marriages, joker bonuses, penalties — each line item visible
- Running match totals across rounds
- Winner celebration, then one-tap rematch

## 7. Look, sound, and feel (the Bhoos bar)

- Custom card faces and backs — the single highest-impact art spend
- 3+ table themes via a swappable theme system (classic, dark modern, festive/Dashain)
- Animations: cards flying out on deal, draw/discard slides, joker flip, point flyouts, win celebration
- Sounds: shuffle riffle, card snap, select click, win jingle, your-turn chime
- Haptics: subtle buzz on your turn and on wins
- App icon, splash art, store screenshots that don't look like a side project

## 8. Progression and retention (v2+)

- Virtual coins: starting stack, win/loss payouts, daily login bonus
- XP/levels and lifetime stats on the profile screen
- Leaderboards and friend lists (arrives with online multiplayer)
- Keep it simple — coins and stats first, everything else later

### Sign-in and cloud save

Planned for right after the MVP.

- Optional Google sign-in through Firebase Auth. Guest play stays available
  at all times, and nothing in the game requires an account.
- For signed-in players, coins and stats are stored in Firestore and synced
  across their devices. Guests keep them on the device only.
- An option to delete the account and its cloud data from inside the app,
  which Google Play requires for any app that lets players create an account.

## 9. Monetization — play-money only

- No real-money wagering, ever — stores will reject it
- Rewarded video ads for extra coins; banners only on non-game screens, never mid-hand
- Theme/card-back shop (coins or small in-app purchases)
- Remove-ads purchase

## 10. App-side technical must-haves

- Rules engine completely separate from UI — the engine decides, the UI only displays
- Save/restore mid-game state (app killed or call comes in → resume the hand)
- Offline-first: full bot play with no connection
- Crash reporting (e.g., Firebase Crashlytics) from the first beta
- Basic analytics: where players quit, which modes get played — tells you what to fix

## 11. Release checklist

- Closed beta with friends/family → fix every confusion → open release
- Android first (Play Store, $25 one-time); iOS later ($99/year)
- Store listing copy, screenshots, privacy policy page (required)

---

## Build order

1. Rules engine + scoring (tested)
2. Table screen + Quick Play vs bots
3. Scoreboard + results screens
4. Home/lobby + settings + How to Play
5. Sounds + animations pass
6. Art + themes + haptics polish
7. Beta → ship → local multiplayer → online