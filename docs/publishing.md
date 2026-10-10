# Publishing to Google Play

Everything needed to put the app on Google Play, in order. The store copy,
screenshots and feature graphic are in [`store/listing.md`](store/listing.md).

## 1. Create the upload key (once)

The upload key signs every release you upload. Google keeps the key that
signs what players download (Play App Signing), so if the upload key is ever
lost it can be reset through the Play Console — but keep it safe and backed
up anyway, outside this repository.

```sh
keytool -genkeypair -v \
  -keystore ~/keys/marriage-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` asks for a password and your name; choose a strong password and
keep it in your password manager.

Then create `android/key.properties` (already ignored by git — never commit
it):

```properties
storePassword=<the password>
keyPassword=<the password>
keyAlias=upload
storeFile=/Users/<you>/keys/marriage-upload.jks
```

With that file present, release builds are signed with the upload key;
without it they fall back to the debug key, which is fine for trying a build
on a phone but is refused by the store.

## 2. Build the app bundle

Bump the version in `pubspec.yaml` for every upload: `version: 1.0.0+1` is
the version name players see (`1.0.0`) and a build number that must go up
each time (`+1`, `+2`, …).

```sh
flutter test
flutter build appbundle --release
```

The bundle is `build/app/outputs/bundle/release/app-release.aab`. Google
Play builds a download for each kind of phone from it, so players get only
what their phone needs.

## 3. Set up the Play Console (once)

1. Create a developer account at play.google.com/console ($25, once).
2. **Create app**: name *Marriage – Nepali Card Game*, a game, free.
3. **Store listing**: the descriptions, icon (512 × 512, from
   `assets/branding/icon.png`), feature graphic and phone screenshots from
   `docs/store/`.
4. **App content**:
   - Privacy policy: the URL of `docs/privacy-policy.md` once published.
   - Ads: none. App access: everything is available without signing in.
   - Content rating: answer the questionnaire; see the notes in
     `store/listing.md` about coins (play money only, never bought or
     cashed out).
   - Target audience: adults and teens; not designed for children.
   - Data safety: no data collected or shared; the network permission is
     used only for games on the same Wi-Fi.
5. **Play App Signing**: accept Google's management of the app signing key
   when uploading the first bundle.

## 4. Closed test, then release

1. **Testing → Closed testing**: create a track, add friends' Google
   accounts as testers, upload the bundle, and share the opt-in link.
   New personal developer accounts must run a closed test with enough
   testers for long enough before applying for production; the Play
   Console shows the current requirement.
2. Fix what testers report. Play's **Android vitals** shows crashes and
   freezes from testers' phones without the app collecting anything itself.
3. **Production**: promote the tested release, or upload a new bundle, and
   send it for review.

## Every release after that

```sh
# bump version: 1.0.1+2
flutter test
flutter build appbundle --release
```

Upload the bundle to the testing track first, then promote it.
