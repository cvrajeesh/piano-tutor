# Localization

Middle C, the app and the website, is written in English and translated into:

| Language | Folder / file | Website | Note names |
| --- | --- | --- | --- |
| English (source) | `en` | `/` | C D E F G A B |
| Spanish | `es` | `/es/` | Do Re Mi Fa Sol La Si |
| French | `fr` | `/fr/` | Do Ré Mi Fa Sol La Si |
| German | `de` | `/de/` | C D E F G A H (Fis, Es, B) |
| Italian | `it` | `/it/` | Do Re Mi Fa Sol La Si |
| Portuguese (Brazil) | `pt-BR` | `/pt-br/` | Dó Ré Mi Fá Sol Lá Si |
| Japanese | `ja` | `/ja/` | ド レ ミ ファ ソ ラ シ |
| Chinese (Simplified) | `zh-Hans` | `/zh-hans/` | C D E F G A B |
| Korean | `ko` | `/ko/` | 도 레 미 파 솔 라 시 |

Every language has its own files, so it can be translated, reviewed and changed on its own.
The translations were drafted by machine and still need a review by a native speaker who
plays the piano before release.

## Where the text lives

**The app** — `Sources/PianoTutor/Resources/<language>.lproj/`

| File | What | Keys |
| --- | --- | --- |
| `Localizable.strings` | The app's own text: buttons, settings, messages | The English text, as written in the Swift code |
| `Localizable.stringsdict` | Text whose wording depends on a number ("1 wrong key", "3 wrong keys") | Same |
| `Course.strings` | The course (units, lessons, every step) and the song library | The English text in `Sources/PianoTutorCore/CourseContent.swift` and `SongLibrary.swift` |
| `InfoPlist.strings` | What the system shows for the app, such as the microphone permission prompt | `Info.plist` keys |

Xcode builds the `.lproj` folders into the iPhone, iPad and Mac App Store apps, and
`scripts/build-app.sh` copies them into the `.app` it makes. `swift run` has no app bundle,
so it always runs in English.

**The website** — `site/locales/<language>.json`, one file per language, used by the page
templates in `site/templates`. The unit titles, song names and song-level headings on the
home page are not in these files: `scripts/build-site.py` takes them from the app's
`Course.strings` and `Localizable.strings`, so the site always says what the app says. The
cookie banner's text is in the locale files too (`common.cookie_*`): every page carries it in a
`<template id="cookie-banner">` in its language, which `site/consent.js` shows.

## How the app picks a language

The app follows the system: it uses the first of the user's preferred languages that it has a
translation for, and English otherwise. People can choose a different language for Middle C
alone, in Settings → Middle C → Language on iPhone and iPad, and in System Settings → General
→ Language & Region → Applications on a Mac; the app's own Settings screen points there. There
is deliberately no language picker inside the app, as Apple recommends.

Changing the language restarts the app, so text is looked up when it is shown and note names
are fixed at launch. The app's link to the website (`Links.website`) opens the site in the same
language, such as `/fr/`.

## Writing code that can be translated

- In SwiftUI, a string literal is looked up in `Localizable.strings`:
  `Text("Volume")`, `Button("Try again")`, `Toggle("Metronome", …)`. A `String` variable is
  shown as it is, so text kept in a variable is translated where it is made, with
  `String(localized: "…", comment: "…")`.
- Give a `comment:` whenever the meaning isn't obvious from the text alone (a single word, a
  button, anything with a placeholder). Translators see it.
- Never build sentences from pieces (`"Connect to your " + deviceName`). Word order and the
  words around a noun change from language to language (German "deinen Mac" but "dein iPad").
  Use interpolation for values (`String(localized: "That was \(note).")`), and write the whole
  sentence out for each case otherwise (see `Platform.Device` in `Support.swift`).
- Use plural rules for counts (`Localizable.stringsdict`), not `count == 1 ? … : …`.
- Format numbers, percentages and durations with Foundation's formatters
  (`Text(value, format: .percent)`, `Measurement(…).formatted()`), not by hand: "85 %" in
  French, "85%" in English.
- Don't upper-case text yourself: `.textCase(.uppercase)` does it the right way for the language.
- Don't assume text fits. German is often a third longer than English and Japanese is
  shorter but taller. Let text wrap or scale (`.minimumScaleFactor`), and use
  `GraphicsContext.drawFitted` for labels drawn in a `Canvas`.
- Note names come from `NoteNaming.current` (in PianoTutorCore), never from `Pitch.name`,
  which is the English spelling used inside the code and the tests.
- The computer keys that play notes on a Mac are matched by position, not letter, and their
  labels are read from the user's keyboard layout (`ComputerKeyboard` in `InputHub.swift`),
  so the piano row works the same on AZERTY and QWERTZ keyboards.
- "Middle C" the app is a brand and is never translated; Middle C the note is.

## Changing English text

The key of every translation is its English text, so changing the English changes the key.

1. Change the text in the Swift code (or in `CourseContent.swift` / `SongLibrary.swift`).
2. Update the key and the English value in `en.lproj`, and in every other language update
   the key and translate the new text.
3. Run `swift test`. `LocalizationTests` fails if `Course.strings` doesn't match the course,
   if a language is missing a string or has one English doesn't, or if a translation lost or
   gained a placeholder.

For the website, change `site/locales/en.json` and the same key in the other languages, then
run `uv run scripts/build-site.py`, which fails if a language is missing a key.

`python3 scripts/check-translations.py [language…]` checks one language (or all) in both the
app and the website: missing or extra keys, empty translations, and placeholders and HTML
tags that don't match English.

## Adding a language

1. Copy `Sources/PianoTutor/Resources/en.lproj` to `<code>.lproj` (an Apple language code:
   `nl`, `pt-PT`, `zh-Hant`) and translate the values, keeping the keys.
2. In `.stringsdict`, give the plural forms the language uses
   ([CLDR plural rules](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html));
   every language needs `other`.
3. Copy `site/locales/en.json` to `site/locales/<code>.json` and translate it. Add the
   language to `LANGUAGES` in `scripts/build-site.py` (its folder, Open Graph locale and its
   name in its own language), and to `LANGUAGES` in `scripts/check-translations.py` and in
   `Tests/PianoTutorCoreTests/LocalizationTests.swift`. Mention it in the website FAQ.
4. If the language has its own note names, add them to `NoteNaming` and a test for them.
5. Run `swift test`, `python3 scripts/check-translations.py <code>` and
   `uv run scripts/build-site.py`, then run the app in the new language to check that nothing
   is cut off: in Xcode, Product → Scheme → Edit Scheme → Run → Options → App Language, or
   from a terminal:

   ```bash
   "build/Middle C.app/Contents/MacOS/PianoTutor" -AppleLanguages "(de)"
   ```

## Translating with tools

The `.strings` files can be edited in any text editor, or handed to a translator or a
translation service as they are. To work in XLIFF instead (the format most translation tools
use), generate the Xcode project and run:

```bash
xcodegen generate
xcodebuild -exportLocalizations -project PianoTutor.xcodeproj -localizationPath build/loc -exportLanguage fr
# … translate build/loc/fr.xcloc …
xcodebuild -importLocalizations -project PianoTutor.xcodeproj -localizationPath build/loc/fr.xcloc
```

## Conventions for translators

- Friendly and plain, like a good teacher: "tu" in French, Italian and Spanish, "du" in
  German, "você" in Portuguese, polite です・ます in Japanese, 해요체 in Korean, 你 in Chinese.
- Use the names Apple uses for its own settings in each language.
- Note names follow the table above, everywhere: in the lesson text as well as on the keys.
  Octave numbers follow scientific pitch notation in every language, so Middle C is C4, Do4,
  ド4 (not the Do3 of the French tradition, or Yamaha's C3).
- Song titles use the name the tune is known by in that language when there is one (きらきら星,
  Hymne à la joie), and the original title otherwise.
- The privacy policy says in every translation that the English version is the one that applies.

## The App Store listing

The App Store text and screenshot captions are translated too, in `fastlane/metadata` and
`fastlane/screenshot_captions.json`. They use the same terms and tone as the app, so when
a mode, unit or song title changes here, change it there as well. See
[App Store listing](app-store-listing.md#languages).

## Not translated yet

- The screenshots on the website and in `docs/screenshots` show the English app, and so
  do the App Store screenshots, under translated captions. Captures of the translated app
  go in `docs/screenshots/<locale>/<device>/`, where the App Store screenshots pick them
  up (see [App Store listing](app-store-listing.md#screenshots-of-the-translated-app)).
