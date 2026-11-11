# App Store listing

Everything people see on the App Store page, and everything App Review is told, lives in
the repository and is uploaded by fastlane: the text, the screenshots, the categories,
the age rating, the notes for the reviewer and the App Privacy answers. Change a file,
merge it, and the next upload carries it. You don't edit the listing in App Store
Connect.

For how builds get to TestFlight and the App Store, see the
[release process](release-process.md). For the one-time setup, see
[App Store setup](app-store-setup.md).

## What's where

| File | App Store Connect field | Limit |
| --- | --- | --- |
| `fastlane/metadata/<locale>/name.txt` | App name | 30 characters |
| `fastlane/metadata/<locale>/subtitle.txt` | Subtitle | 30 characters |
| `fastlane/metadata/<locale>/promotional_text.txt` | Promotional text | 170 characters |
| `fastlane/metadata/<locale>/description.txt` | Description | 4000 characters |
| `fastlane/metadata/<locale>/keywords.txt` | Keywords, comma-separated | 100 bytes |
| `fastlane/metadata/<locale>/support_url.txt` | Support URL | |
| `fastlane/metadata/<locale>/marketing_url.txt` | Marketing URL | |
| `fastlane/metadata/<locale>/privacy_url.txt` | Privacy Policy URL | |
| `fastlane/metadata/copyright.txt` | Copyright | |
| `fastlane/metadata/primary_category.txt`, `secondary_category.txt` | Categories (Education, Music) | |
| `fastlane/metadata/review_information/notes.txt` | App Review notes | 4000 characters |
| `fastlane/age_rating.json` | Age rating questionnaire | |
| `fastlane/app_privacy_details.json` | App Privacy ("Data Not Collected") | |
| `fastlane/screenshot_captions.json` | The screenshots, their order and their captions | |
| `scripts/store-assets.py` | Makes the screenshots | |
| `CHANGELOG.md` | What's New in This Version | 4000 characters |

The same text is used for the iPhone/iPad app and the Mac app.

## Languages

The listing is in nine languages, one folder each in `fastlane/metadata`:

| Folder | App Store Connect language |
| --- | --- |
| `en-US` | English (U.S.), the primary language |
| `fr-FR` | French |
| `de-DE` | German |
| `es-ES` | Spanish (Spain) |
| `it` | Italian |
| `pt-BR` | Portuguese (Brazil) |
| `ja` | Japanese |
| `ko` | Korean |
| `zh-Hans` | Chinese (Simplified) |

The English text uses the same British English as the app and the website. The
translations follow the English, with a few choices worth keeping when they change:

- **The name stays "Middle C"** in every language, as a brand. The text explains it
  the first time with the local name for the note: *do central* (French, Spanish),
  *do centrale* (Italian), *dó central* (Portuguese), *mittleres C* (German),
  真ん中のド (Japanese), 가운데 도 (Korean), 中央C (Chinese).
- **German speaks to the reader as *du***, which is usual for apps. French, Italian,
  Spanish and Portuguese use the form usual in those stores (*vous*, *tu*, *tú*,
  *você*).
- **Song titles** are given their usual local names where they have one (*Hymne à la
  joie*, エリーゼのために, 欢乐颂). Traditional English tunes keep their English names.
- **Keywords** are chosen per language, not translated word for word, and leave out
  words already in the subtitle. Keywords are limited to 100 **bytes**, and Chinese,
  Japanese and Korean characters take 3 bytes each, so those lists are short.

**What's New** comes from the English changelog for every language (see
[What's New](#whats-new)); App Store Connect needs it in each language the version
has, and accepts English text in any of them.

To add a language, copy a folder in `fastlane/metadata`, name it with the
[App Store Connect locale code](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations)
(deliver's list is in `fastlane_core/languages.rb`), translate the files, and add the
same code to `fastlane/screenshot_captions.json`. `scripts/store-assets.py --check`
fails until both are there. To have the store show a language in another region too
(Spanish (Mexico), Portuguese (Portugal), French (Canada), Chinese (Traditional)), copy
the nearest folder and adapt it.

If the app record's primary language isn't English (U.S.), rename `en-US` (and its
key in `screenshot_captions.json`) to match it; otherwise deliver adds the English
text as one more language and the primary one stays empty.

This is the store listing only. The app itself is localised separately, in its
String Catalog; until it is, the screenshots show the English app with translated
captions (see [Screenshots](#screenshots)).

## The text

Write it the way the website is written: plain, specific, no superlatives. Some things
App Review and the App Store care about:

- **Name and subtitle** are what search weighs most. Their words don't need repeating
  in the keywords.
- **Keywords** are single words or short phrases separated by commas, with no spaces
  after the commas. Don't use other apps' names or trademarks. Plurals and the app's
  category are matched without being listed.
- **Promotional text** can be changed at any time without a new version (it's
  uploaded with the next `metadata` run). The description, keywords and name can
  only change with a new version.
- **Don't mention** other platforms (Android, Windows), prices, "beta", or features
  that aren't in the build. The `release` lane runs fastlane's
  [precheck](https://docs.fastlane.tools/actions/precheck/) before it submits, and
  stops on these.

The URLs point at the website in `site/`, which has to be live before the first
submission: App Review opens the support and privacy pages.

### Checking the text

```bash
uv run scripts/store-assets.py --check
```

checks that every language has the required files and that nothing is over Apple's
limits, and warns about keywords already in the name or subtitle. The Store listing
workflow (`.github/workflows/store-listing.yml`) runs it on every pull request that
touches the listing, so an over-long description fails the PR rather than the release.

## Screenshots

`scripts/store-assets.py` makes the App Store screenshots from the captures in
`docs/screenshots`, so the store, the website and the README all show the same screens.
Each one puts a capture on the app's navy background with a caption above it. There is
one set per language:

| Set | Size | Made from | Folder |
| --- | --- | --- | --- |
| iPhone 6.9" | 1320 × 2868 | `docs/screenshots/iphone/*-portrait.png` | `fastlane/screenshots/ios/<locale>/iphone-*.png` |
| iPad 13" | 2752 × 2064 | `docs/screenshots/ipad/*-landscape.png` | `fastlane/screenshots/ios/<locale>/ipad-*.png` |
| Mac | 2880 × 1800 | `docs/screenshots/macos/*.png` | `fastlane/screenshots/mac/<locale>/mac-*.png` |

App Store Connect only needs the largest iPhone and iPad sizes; it scales them down
for smaller devices. deliver works out the device from the image size, and uploads
each set in file-name order.

### Screens and captions

`fastlane/screenshot_captions.json` lists the six screens in the order they appear in
the store (`screens`), and each language's headline and caption for every screen
(`captions`). The first two or three show in search results, so they carry the main
idea:

1. Practice exercise: *Piano lessons that listen*
2. Song in practice mode: *The music waits for you*
3. In-time mode: *Then play it in time*
4. Course map: *27 short lessons*
5. Song library: *18 songs to learn*
6. Free play: *See what you play*

To change a caption, edit it there. To show a different screen, add its captures to
`docs/screenshots` (all three devices, with the same names), add its name to
`screens` and give it a caption in every language.

Captions wrap onto two lines when they need to, with the lines kept even, and
"Middle C" is never split. Japanese and Chinese have no spaces to break at, so their
captions mark the places a line may break with `|`, which isn't drawn:
`"あなたの演奏を聴く|ピアノレッスン"`. Without one, a long line breaks between any two
characters, which can split a word.

Each language has its own fonts: San Francisco, as in the app, and for Japanese,
Korean and Chinese the system fonts Hiragino Sans, Apple SD Gothic Neo and Hiragino
Sans GB.

### Screenshots of the translated app

Until the app itself is translated, every language uses the English captures, under
translated captions; App Store Connect accepts that. When the app is translated, take
each language's captures with the same names as the English ones and put them in
`docs/screenshots/<locale>/<device>/`, for example
`docs/screenshots/ja/iphone/song-portrait.png`. The script uses a language's own
capture whenever there is one, screen by screen, and the English one otherwise.

The screenshots aren't committed (`fastlane/screenshots` is ignored by git). The
`release` and `metadata` lanes make them before every upload, and the Store listing
workflow attaches them to its run as the `store-screenshots` artifact so you can look
at them in a pull request. To make them on your Mac:

```bash
uv run scripts/store-assets.py                 # every language
uv run scripts/store-assets.py --locale ja     # one language
open fastlane/screenshots
```

The fonts are found in macOS. Elsewhere the script falls back to another font, which
can't draw Japanese, Korean or Chinese, so screenshots are only made on macOS:
uploads and the Store listing workflow both run there.

Each upload replaces all the screenshots for that platform (`overwrite_screenshots`),
so screens taken out of `screens` disappear from the store too.

## What's New

For every version after the first, the Fastfile fills in **What's New in This Version**
from that version's section of `CHANGELOG.md`, which Release Please writes from the PR
titles. Links, commit hashes and scopes are removed, and the headings become *New*,
*Fixes* and *Faster*:

```
New
• Play songs at 60% speed

Fixes
• Reconnect the keyboard after sleep
```

So PR titles are also store copy: write them for the person reading the App Store
page. To word it differently for one release, edit the changelog in a `docs:` PR
before running the `release` lane. App Store Connect has no What's New for an app's
first version, and deliver leaves it out then.

The changelog is in English, and every language gets the English text. To give a
language its own What's New for a release, run the `release` lane without
**Submit for review**, edit What's New in App Store Connect, then submit there.

## App Review

`fastlane/metadata/review_information/notes.txt` tells the reviewer how to try the
app without a piano: the on-screen keyboard, the computer keyboard on a Mac, and
**Unlock all lessons**. It also explains why the app uses the microphone, and that it
is optional. Keep it in step with the app when those change.

The contact details App Review needs (name, email, phone) stay out of the repository.
Set them once, either in App Store Connect under **App Review Information**, or as
`REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`, `REVIEW_EMAIL` and `REVIEW_PHONE` in
`fastlane/.env` and as repository secrets of the same names. When they're unset,
fastlane leaves the values already in App Store Connect alone.

No demo account is needed; the app has no sign-in.

## Age rating

`fastlane/age_rating.json` answers Apple's age rating questionnaire: no violence,
no mature themes, no gambling or contests, no user-generated content, no chat, no
advertising, no unrestricted web access (the feedback link in Settings opens the browser). The
app comes out at **4+**. If the app ever adds something on that list, change the
answer here; it's uploaded with every `release` and `metadata` run.

## App Privacy

`fastlane/app_privacy_details.json` says **Data Not Collected**, which matches the
[privacy policy](../site/privacy.html) and `Support/iOS/PrivacyInfo.xcprivacy`. Apple's
API keys can't edit App Privacy, so this one is uploaded by its own lane, which logs in
with your Apple ID:

```bash
FASTLANE_USER=you@example.com bundle exec fastlane privacy
```

It asks for your password and a two-factor code, so it runs on your Mac, not on CI.
Run it once before the first submission, and again only if the answers change.

## Other submission answers

The `release` lane answers the remaining submission questions:

- **Export compliance:** the app uses no non-exempt encryption
  (`ITSAppUsesNonExemptEncryption` is `NO` in `project.yml`), so there's no question
  per build.
- **Content rights:** the app contains third-party content (the Bravura music font,
  under the SIL Open Font License, and public-domain tunes), and you have the rights
  to use it.
- **Advertising identifier:** not used.
- **Release:** manual. An approved version waits as *Pending Developer Release* until
  you click **Release This Version**.

Price and availability aren't uploaded: set them once in App Store Connect under
**Pricing and Availability**.

## Uploading

| Command | What it uploads |
| --- | --- |
| `bundle exec fastlane ios metadata` / `mac metadata` | The listing, screenshots, age rating and review notes, to the version in `project.yml`. No build. Creates that version in App Store Connect if it doesn't exist |
| `bundle exec fastlane ios release` / `mac release` | A new build and all of the above. Add `submit:true` to submit for review |
| `bundle exec fastlane privacy` | The App Privacy answers |

From GitHub, run the Release workflow by hand with lane `metadata` or `release` (see
[Running the Release workflow by hand](release-process.md#running-the-release-workflow-by-hand)).

A version that is waiting for review or live can't take a new description, keywords or
screenshots; App Store Connect only accepts those for a version that is still being
prepared. The promotional text and the URLs can change at any time.

## Before the first submission

1. The website is live, with the support and privacy pages.
2. The App Review contact is set (see [App Review](#app-review)).
3. `bundle exec fastlane privacy` has been run once.
4. Pricing and Availability is set in App Store Connect.
5. A build of the version is in TestFlight and has been tried on a device and a Mac.
6. `uv run scripts/store-assets.py` and a look at `fastlane/screenshots`.
7. Run the Release workflow from the tag with lane `release` and **Submit for review**
   ticked, or `bundle exec fastlane ios release submit:true` and
   `bundle exec fastlane mac release submit:true` from your Mac.

## Things App Review may ask about

- **Tips.** The app has no tip or donation link: Apple's guideline 3.1.1 asks for
  tips to go through In-App Purchase, and App Review rejects apps that link to an
  outside tip page. Buy Me a Coffee is only on the website. Don't add it back to the
  app, or mention it in the store text; an in-app tip would have to be an In-App
  Purchase.
- **The microphone.** The review notes and the permission prompt both explain that
  audio is analysed on the device and never recorded.
- **USB-MIDI keyboards.** The reviewer won't have one. The notes explain the
  on-screen keyboard.
