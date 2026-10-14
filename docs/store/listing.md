# Play Store listing

Draft copy and assets for the Google Play listing. The screenshots and feature
graphic are rendered from the app itself, so they always match it:

```sh
flutter test tool/render_screenshots.dart   # screenshots/
flutter test tool/render_branding.dart      # feature-graphic.jpg (and the icon)
```

## App name (30 characters max)

Marriage – Nepali Card Game

## Short description (80 characters max)

Play Marriage, the Nepali rummy card game, offline against smart bots.

## Full description

Marriage is the much-loved Nepali card game, played with three decks, jokers
and a lot of table talk. Now you can play it anywhere, offline, against
computer players who think like real opponents.

**Play the real game**
- Three decks, 21 cards each, 2 to 5 players
- Show your three pure sequences or tunnellas to see the joker
- Tiplu, jhiplu, poplu and alter cards, marriages and maal
- Win with sets or with seven doublees
- A full scoreboard: every maal share, payment and penalty, round by round

**Play it your way**
- Three ways to settle the maal: Standard, Kidnap or Murder
  - Standard: players who haven't seen the joker lose their maal
  - Kidnap: the winner takes the maal of players who haven't seen the joker
  - Murder: players who haven't seen the joker also pay the winner's maal
- House rules to match how your family plays: add man cards and the
  Superman, count the alter as maal or not, and turn the joker discard
  penalty on or off
- Your rules carry over to every game you start, and when you host, everyone
  at the table plays by them

**Bots worth beating**
- Easy, Medium and Hard, each with its own style of play
- Bots get tougher as you move up the stake tables
- Hard bots remember every discard and won't feed you the card you need
- Bots take a moment to think, so the table feels alive

**Made for your thumbs**
- Drag a card up onto the pile, or just flick it, to discard
- Long-press to rearrange your hand, or sort it with one tap
- Group your sets and a helper shows how close you are to showing or winning
- A warning before you throw away a joker and pay the penalty

**Looks and feels like a real table**
- Printed-style cards with classic court figures
- Three tables: Classic green, Midnight, and festive Dashain with kites
- Cards that deal, slide and land, and a celebration when you win
- Sounds and gentle vibration on your turn, all switchable

**Play with friends**
- Pass and play: 2 to 5 people share one phone or tablet
- The table hides your cards while the phone changes hands, and shows
  what everyone did since your last turn
- Or play on your own phones over Wi-Fi or a hotspot: one phone hosts and
  shows a short code, friends type it in to join, and bots fill any empty
  seats. No internet needed

Quick Play starts a full table in one tap; Single Player lets you pick a stake
table, from 5 coins a point upwards, with higher tables unlocking as you play.
Coins are just for fun: you can't buy them and they can't be cashed out.

## Category and tags

- Category: Games → Card
- Tags: Card, Rummy, Offline, Single player

## Graphics

| Asset | File | Size |
|---|---|---|
| App icon | `assets/branding/icon.png` | 1024 × 1024 (Play wants 512 × 512; scale it down) |
| Feature graphic | `docs/store/feature-graphic.jpg` | 1024 × 500 |
| Phone screenshots | `docs/store/screenshots/1-home.jpg` … `7-pass.jpg` | 1920 × 1080 |

Screenshots, in order: the home screen, a full table, the Dashain table,
choosing a stake table and mode, winning a round, the scoreboard, and passing
the device between friends.

## Content rating notes

For the IARC questionnaire in Play Console:

- No violence, language, or user-to-user communication.
- Coins are won and lost per point at the table, but can't be bought, sold,
  or exchanged for anything. Answer the "simulated gambling" question
  carefully: Marriage is a rummy-style card game played for points, with no
  betting of real money. The questionnaire's own definitions decide the
  answer, so read them before choosing.

## Data safety

The release build asks for one permission, network access. It's used to play
with friends' phones on the same Wi-Fi or hotspot, and to send crash reports
(Firebase Crashlytics) and a few anonymous game events (Google Analytics for
Firebase). The player's name, settings and coin balance stay on the device,
in the app's own storage, and a player's name is shown only to the friends at
their table; none of them is in the reports or events.

For the form:

- Data collected:
  - App info and performance → Crash logs, Diagnostics (Crashlytics)
  - App activity → App interactions (Analytics: screens and game events)
  - Device or other IDs → the Firebase installation ID
- Purpose: Analytics; App functionality (crash reports)
- Collection is required (no in-app switch), processed ephemerally: no
- Data shared: none (Google processes it as a service provider)
- Encrypted in transit: yes
- Users can request deletion: no account exists, so there's nothing tied to
  a person; Analytics data expires under the project's retention setting
- Privacy policy: https://mohitdha1.github.io/marriage-game/privacy-policy

## Before publishing

These are Phase 6 jobs, listed so they aren't forgotten:

1. Change the application ID from `com.example.marriage_game` (Play rejects
   `com.example`) to one based on a domain or name that's yours.
2. Create an upload key and set up release signing.
3. Build an app bundle: `flutter build appbundle`.
4. Publish the privacy policy page and add its link.
