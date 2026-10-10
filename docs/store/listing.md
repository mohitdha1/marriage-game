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

**Bots worth beating**
- Easy, Medium or Hard, each with its own style of play
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

Quick Play starts a full table in one tap; Single Player lets you choose the
players and the bots. Coins are just for fun: you can't buy them and they
can't be cashed out.

## Category and tags

- Category: Games → Card
- Tags: Card, Rummy, Offline, Single player

## Graphics

| Asset | File | Size |
|---|---|---|
| App icon | `assets/branding/icon.png` | 1024 × 1024 (Play wants 512 × 512; scale it down) |
| Feature graphic | `docs/store/feature-graphic.jpg` | 1024 × 500 |
| Phone screenshots | `docs/store/screenshots/1-home.jpg` … `7-pass.jpg` | 1920 × 1080 |

Screenshots, in order: the home screen, a full table, the Dashain table, the
game setup, winning a round, the scoreboard, and passing the device between
friends.

## Content rating notes

For the IARC questionnaire in Play Console:

- No violence, language, or user-to-user communication.
- Coins are won and lost per point at the table, but can't be bought, sold,
  or exchanged for anything. Answer the "simulated gambling" question
  carefully: Marriage is a rummy-style card game played for points, with no
  betting of real money. The questionnaire's own definitions decide the
  answer, so read them before choosing.

## Data safety

The release build asks for one permission, network access, used only to play
with friends' phones on the same Wi-Fi or hotspot; nothing goes to the
internet or any server. It collects and shares no data. The player's name,
settings and coin balance stay on the device, in the app's own storage, and a
player's name is shown only to the friends at their table.

- Data collected: none
- Data shared: none
- Play Console still asks for a privacy policy link; a short page saying the
  app collects no data, hosted anywhere public (for example GitHub Pages),
  covers it.

## Before publishing

These are Phase 6 jobs, listed so they aren't forgotten:

1. Change the application ID from `com.example.marriage_game` (Play rejects
   `com.example`) to one based on a domain or name that's yours.
2. Create an upload key and set up release signing.
3. Build an app bundle: `flutter build appbundle`.
4. Publish the privacy policy page and add its link.
